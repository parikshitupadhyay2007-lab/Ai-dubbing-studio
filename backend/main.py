import asyncio
import json
import os
import shutil
import subprocess
import uuid
import wave
import array

from pathlib import Path
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel, Field
from faster_whisper import WhisperModel

import edge_tts
import httpx

ROOT = Path(__file__).parent / 'jobs'
ROOT.mkdir(exist_ok=True)

app = FastAPI(title='OtakuDub API')
model = None
MAX_TRANSLATION_ATTEMPTS = 3

VOICES = {
    'hi': {
        'natural': ['hi-IN-MadhurNeural', 'hi-IN-SwaraNeural'],
        'expressive': ['hi-IN-MadhurNeural', 'hi-IN-SwaraNeural']
    },
    'en': {
        'natural': ['en-US-GuyNeural', 'en-US-JennyNeural', 'en-US-AriaNeural'],
        'expressive': ['en-US-ChristopherNeural', 'en-US-AriaNeural', 'en-US-DavisNeural']
    }
}


def run(*args):
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError(p.stderr[-1500:])


def jobdir(jid):
    if not jid.isalnum() or not (ROOT / jid).exists():
        raise HTTPException(404, 'Project not found')
    return ROOT / jid


def save_project(path, data):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
    temporary.replace(path)


@app.get('/health')
def health():
    return {'ok': True}


class TranslationError(Exception):
    pass


def retry_delay(response, attempt):
    fallback = min(2 ** attempt, 8)
    header = response.headers.get('Retry-After')
    if not header:
        return fallback
    try:
        seconds = float(header)
    except ValueError:
        try:
            retry_date = parsedate_to_datetime(header)
            if retry_date.tzinfo is None:
                retry_date = retry_date.replace(tzinfo=timezone.utc)
            seconds = (retry_date - datetime.now(timezone.utc)).total_seconds()
        except (ValueError, TypeError, OverflowError):
            return fallback
    return max(0, seconds)


async def translate_dialogue(text: str, target: str, source: str = 'ja'):
    if not text.strip():
        return ''
    if source == target:
        return text
    async with httpx.AsyncClient(timeout=20.0) as client:
        for attempt in range(1, MAX_TRANSLATION_ATTEMPTS + 1):
            try:
                response = await client.get(
                    'https://api.mymemory.translated.net/get',
                    params={'q': text, 'langpair': f'{source}|{target}'}
                )
                print('TRANSLATION HTTP:', 'status=', response.status_code,
                      'attempt=', attempt, 'source=', source, 'target=', target, flush=True)
                if response.status_code == 429:
                    try:
                        error_data = response.json()
                    except ValueError:
                        error_data = {}
                    if error_data.get('quotaFinished'):
                        raise TranslationError('MyMemory translation quota exhausted. Please try again after the quota resets.')
                    delay = retry_delay(response, attempt)
                    if attempt >= MAX_TRANSLATION_ATTEMPTS:
                        raise TranslationError('Translation provider is rate-limiting requests. Please try again later.')
                    if delay > 15:
                        raise TranslationError('Translation provider requested a long cooldown. Please try again later.')
                    print('TRANSLATION RETRY:', 'reason=429', 'wait_seconds=', delay, flush=True)
                    await asyncio.sleep(delay)
                    continue
                if response.status_code in (500, 502, 503, 504):
                    if attempt >= MAX_TRANSLATION_ATTEMPTS:
                        raise TranslationError('Translation provider is temporarily unavailable. Please try again later.')
                    delay = min(2 ** attempt, 8)
                    print('TRANSLATION RETRY:', 'status=', response.status_code,
                          'wait_seconds=', delay, flush=True)
                    await asyncio.sleep(delay)
                    continue
                if response.status_code >= 400:
                    raise TranslationError(f'Translation provider rejected the request (HTTP {response.status_code}).')
                result = response.json()
                api_status = str(result.get('responseStatus'))
                quota_finished = result.get('quotaFinished', False)
                print('TRANSLATION API:', 'status=', api_status,
                      'quota_finished=', quota_finished, flush=True)
                if quota_finished:
                    raise TranslationError('MyMemory translation quota exhausted. Please try again after the quota resets.')
                if api_status != '200':
                    raise TranslationError(f'Translation API returned an unsuccessful status ({api_status}).')
                translated = result.get('responseData', {}).get('translatedText', '')
                if not isinstance(translated, str) or not translated.strip():
                    raise TranslationError('Translation API returned empty text.')
                return translated.strip()
            except TranslationError:
                raise
            except (httpx.TimeoutException, httpx.TransportError) as e:
                print('TRANSLATION NETWORK ERROR:', type(e).__name__,
                      'attempt=', attempt, flush=True)
                if attempt >= MAX_TRANSLATION_ATTEMPTS:
                    raise TranslationError('Translation network request failed. Please try again later.')
                await asyncio.sleep(min(2 ** attempt, 8))
            except ValueError:
                raise TranslationError('Translation provider returned invalid JSON.')
    raise TranslationError('Automatic translation failed.')


@app.post('/projects')
async def create(file: UploadFile = File(...)):
    jid = uuid.uuid4().hex
    d = ROOT / jid
    d.mkdir()
    suffix = Path(file.filename or 'video.mp4').suffix.lower()
    if suffix not in ('.mp4', '.mov', '.mkv', '.webm', '.mp3', '.wav', '.m4a'):
        raise HTTPException(400, 'Unsupported media format')
    source = d / ('source' + suffix)
    with source.open('wb') as f:
        while chunk := await file.read(1024 * 1024):
            f.write(chunk)
    if source.stat().st_size > 500 * 1024 * 1024:
        shutil.rmtree(d)
        raise HTTPException(413, '500 MB MVP limit')
    run('ffmpeg', '-y', '-i', str(source), '-vn', '-ac', '1', '-ar', '16000', str(d / 'audio.wav'))
    global model
    if model is None:
        model = WhisperModel(os.getenv('WHISPER_MODEL', 'tiny'), device='cpu',
                             compute_type='int8', cpu_threads=1, num_workers=1)
    segments, info = model.transcribe(str(d / 'audio.wav'), vad_filter=True)
    items = [
        {'id': i, 'start': round(s.start, 2), 'end': round(s.end, 2),
         'text': s.text.strip(), 'speaker': 'Character 1', 'translation': ''}
        for i, s in enumerate(segments)
    ]
    print('TRANSCRIPTION COMPLETE:', 'language=', info.language,
          'segments=', len(items), flush=True)
    data = {'id': jid, 'source': source.name, 'source_language': info.language,
            'segments': items, 'translation_cache': {}}
    save_project(d / 'project.json', data)
    return data


class TranslationRequest(BaseModel):
    language: str


@app.post('/projects/{jid}/translate')
async def translate_project(jid: str, req: TranslationRequest):
    if req.language not in ('hi', 'en'):
        raise HTTPException(400, 'Unsupported translation language')
    d = jobdir(jid)
    path = d / 'project.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    source_language = data.get('source_language', 'ja')
    cache = data.setdefault('translation_cache', {})
    pair = f'{source_language}|{req.language}'
    pair_cache = cache.setdefault(pair, {})
    print('TRANSLATION START:', 'source=', source_language, 'target=', req.language,
          'segments=', len(data['segments']), flush=True)
    translated = []
    for segment in data['segments']:
        original = segment['text'].strip()
        if not original:
            result = ''
        elif original in pair_cache:
            result = pair_cache[original]
            print('TRANSLATION CACHE HIT:', 'segment_id=', segment['id'], flush=True)
        else:
            try:
                result = await translate_dialogue(original, req.language, source_language)
            except TranslationError as e:
                print('TRANSLATION FAILED:', 'segment_id=', segment['id'],
                      'reason=', str(e), flush=True)
                save_project(path, data)
                raise HTTPException(503, str(e))
            pair_cache[original] = result
            save_project(path, data)
        translated.append({**segment, 'translation': result})
    data['segments'] = translated
    data['target_language'] = req.language
    save_project(path, data)
    print('TRANSLATION COMPLETE:', len(translated), 'segments', flush=True)
    return data


@app.get('/projects/{jid}')
def get_project(jid: str):
    return json.loads((jobdir(jid) / 'project.json').read_text())


class Segment(BaseModel):
    id: int
    start: float
    end: float
    text: str
    speaker: str
    translation: str = ''


class RenderRequest(BaseModel):
    language: str
    style: str
    segments: list[Segment]
    voices: dict[str, str]


@app.get('/voices')
def voices():
    return VOICES


@app.post('/projects/{jid}/render')
async def render(jid: str, req: RenderRequest):
    d = jobdir(jid)
    data = json.loads((d / 'project.json').read_text())
    if req.language not in VOICES or req.style not in ('natural', 'expressive'):
        raise HTTPException(400, 'Invalid language/style')
    allowed = sum(VOICES[req.language].values(), [])
    for v in req.voices.values():
        if v not in allowed:
            raise HTTPException(400, 'Voice does not match target language')
    if any(not s.translation.strip() for s in req.segments):
        raise HTTPException(400, 'Fill target-language text for every dialogue segment')
    clips = []
    for i, s in enumerate(req.segments):
        voice = req.voices.get(s.speaker)
        if not voice:
            raise HTTPException(400, f'Assign a voice to {s.speaker}')
        mp3 = d / f'clip{i}.mp3'
        wav = d / f'clip{i}.wav'
        rate = '+12%' if req.style == 'expressive' else '+0%'
        await edge_tts.Communicate(s.translation, voice, rate=rate).save(str(mp3))
        run('ffmpeg', '-y', '-i', str(mp3), '-ar', '24000', '-ac', '1', str(wav))
        clips.append((s.start, wav))
    with wave.open(str(d / 'audio.wav')) as f:
        duration = f.getnframes() / f.getframerate()
    total = int((duration + 1) * 24000)
    mix = array.array('h', [0]) * total
    for start, wav in clips:
        with wave.open(str(wav)) as f:
            raw = f.readframes(f.getnframes())
            rate = f.getframerate()
        samples = array.array('h')
        samples.frombytes(raw)
        offset = int(start * rate)
        for i, val in enumerate(samples):
            at = offset + i
            if at >= total:
                break
            mix[at] = max(-32768, min(32767, mix[at] + val))
    with wave.open(str(d / 'dub.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(24000)
        f.writeframes(mix.tobytes())
    source = d / data['source']
    output = d / 'dubbed.mp4'
    run('ffmpeg', '-y', '-i', str(source), '-i', str(d / 'dub.wav'),
        '-map', '0:v:0?', '-map', '1:a:0', '-c:v', 'libx264',
        '-preset', 'veryfast', '-c:a', 'aac', '-shortest', str(output))
    return {'download_url': f'/projects/{jid}/download',
            'note': 'MVP replaces original audio; no music/effects separation.'}


@app.get('/projects/{jid}/download')
def download(jid: str):
    f = jobdir(jid) / 'dubbed.mp4'
    if not f.exists():
        raise HTTPException(404, 'Render the project first')
    return FileResponse(f, media_type='video/mp4', filename='AI-Dubbing-Studio.mp4')


# ------------------------------------
# OTAKUDUB VOICE STUDIO
# ------------------------------------

VOICE_STUDIO_VOICES = {
    'hi-IN-MadhurNeural': 'Hindi - Madhur',
    'hi-IN-SwaraNeural': 'Hindi - Swara',
    'en-US-GuyNeural': 'English - Guy',
    'en-US-JennyNeural': 'English - Jenny',
    'en-US-AriaNeural': 'English - Aria',
    'en-US-ChristopherNeural': 'English - Christopher',
    'en-US-DavisNeural': 'English - Davis',
}


class VoiceoverRequest(BaseModel):
    text: str = Field(min_length=1, max_length=1500)
    voice: str
    style: str = 'natural'


@app.get('/studio/voices')
def studio_voices():
    return VOICE_STUDIO_VOICES


@app.post('/studio/generate')
async def generate_voiceover(req: VoiceoverRequest):
    text = req.text.strip()
    if not text:
        raise HTTPException(400, 'Please enter dialogue.')
    if req.voice not in VOICE_STUDIO_VOICES:
        raise HTTPException(400, 'Unsupported voice.')
    if req.style not in ('natural', 'expressive'):
        raise HTTPException(400, 'Unsupported voice style.')
    rate = '+12%' if req.style == 'expressive' else '+0%'
    try:
        audio = bytearray()
        communicate = edge_tts.Communicate(text, req.voice, rate=rate)
        async for chunk in communicate.stream():
            if chunk['type'] == 'audio':
                audio.extend(chunk['data'])
        if not audio:
            raise RuntimeError('No audio generated')
    except Exception as e:
        print('VOICE STUDIO ERROR:', type(e).__name__, flush=True)
        raise HTTPException(503, 'Voice generation is temporarily unavailable. Please try again.') from e
    return Response(
        content=bytes(audio),
        media_type='audio/mpeg',
        headers={
            'Content-Disposition': 'attachment; filename="OtakuDub-Voiceover.mp3"',
            'Cache-Control': 'no-store',
        },
    )
    
# ------------------------------------
# OTAKUDUB VOICE STUDIO WEBSITE
# ------------------------------------

from fastapi.responses import HTMLResponse

@app.get('/studio', response_class=HTMLResponse)
def voice_studio_website():
    website = Path(__file__).parent / 'studio' / 'index.html'

    if not website.is_file():
        raise HTTPException(
            status_code=404,
            detail='Voice Studio website not found'
        )

    return HTMLResponse(
        content=website.read_text(encoding='utf-8')
    )
# ============================================
# OTAKUDUB V3 — OTAKUMIND FOUNDATION
# ============================================

OTAKUMIND_PERSONALITIES = {
    "spirit": {
        "name": "Unbreakable Spirit",
        "inspiration": "Naruto",
        "description": "Energetic, optimistic and determined.",
        "voice_style": "energetic",
        "voice": {
            "hi": "hi-IN-MadhurNeural",
            "en": "en-US-GuyNeural"
        }
    },
    "shadow": {
        "name": "Shadow Strategist",
        "inspiration": "Sasuke",
        "description": "Reserved, focused and analytical.",
        "voice_style": "calm",
        "voice": {
            "hi": "hi-IN-MadhurNeural",
            "en": "en-US-ChristopherNeural"
        }
    },
    "mentor": {
        "name": "Limitless Mentor",
        "inspiration": "Gojo",
        "description": "Playful, confident and witty.",
        "voice_style": "playful",
        "voice": {
            "hi": "hi-IN-MadhurNeural",
            "en": "en-US-GuyNeural"
        }
    },
    "companion": {
        "name": "Future Companion",
        "inspiration": "Doraemon",
        "description": "Friendly, imaginative and helpful.",
        "voice_style": "friendly",
        "voice": {
            "hi": "hi-IN-SwaraNeural",
            "en": "en-US-JennyNeural"
        }
    },
    "guardian": {
        "name": "Gentle Guardian",
        "inspiration": "Hinata",
        "description": "Thoughtful, gentle and supportive.",
        "voice_style": "gentle",
        "voice": {
            "hi": "hi-IN-SwaraNeural",
            "en": "en-US-AriaNeural"
        }
    },
    "genius": {
        "name": "Mastermind",
        "inspiration": "Light Yagami",
        "description": "Intelligent, articulate and calculating.",
        "voice_style": "analytical",
        "voice": {
            "hi": "hi-IN-MadhurNeural",
            "en": "en-US-ChristopherNeural"
        }
    }
}


@app.get("/otakumind/health")
def otakumind_health():
    return {
        "ok": True,
        "service": "OtakuMind",
        "version": "3.0",
        "personalities": len(OTAKUMIND_PERSONALITIES)
    }


@app.get("/otakumind/personalities")
def get_otakumind_personalities():
    return {
        "personalities": [
            {
                "id": personality_id,
                **profile
            }
            for personality_id, profile
            in OTAKUMIND_PERSONALITIES.items()
        ]
    }


@app.get("/otakumind/personalities/{personality_id}")
def get_otakumind_personality(personality_id: str):
    profile = OTAKUMIND_PERSONALITIES.get(personality_id)

    if profile is None:
        raise HTTPException(
            status_code=404,
            detail="OtakuMind personality not found"
        )

    return {
        "id": personality_id,
        **profile
    }

# ============================================
# OTAKUMIND V3 — GROQ CLOUD CHAT
# ============================================

class OtakuMindHistoryItem(BaseModel):
    role: str
    content: str = Field(min_length=1, max_length=2000)


class OtakuMindChatRequest(BaseModel):
    personality_id: str
    message: str = Field(min_length=1, max_length=2000)
    language: str = 'en'
    history: list[OtakuMindHistoryItem] = Field(default_factory=list)


@app.post('/otakumind/chat')
async def otakumind_chat(req: OtakuMindChatRequest):
    profile = OTAKUMIND_PERSONALITIES.get(req.personality_id)
    if profile is None:
        raise HTTPException(404, 'OtakuMind personality not found')
    if req.language not in ('hi', 'en'):
        raise HTTPException(400, 'Choose Hindi (hi) or English (en)')
    message = req.message.strip()
    if not message:
        raise HTTPException(400, 'Message cannot be empty')

    api_key = os.getenv('GROQ_API_KEY', '').strip()
    if not api_key:
        print('OTAKUMIND: GROQ_API_KEY is missing', flush=True)
        raise HTTPException(503, 'OtakuMind AI is not configured on the server')

    language_instruction = ('Reply naturally in Hindi using Devanagari script.'
                            if req.language == 'hi' else 'Reply naturally in English.')
    system_prompt = (
        'You are OtakuMind, an original fictional anime-inspired AI companion. '
        f'Your personality is {profile["name"]}: {profile["description"]} '
        f'Your conversational style is {profile["voice_style"]}. '
        'Do not claim to be an existing copyrighted anime character or a real person. '
        f'{language_instruction} Be friendly, helpful, and concise. '
        'Keep your reply under 1200 characters so it can be played by the voice studio.'
    )
    messages = [{'role': 'system', 'content': system_prompt}]
    for item in req.history[-12:]:
        if item.role in ('user', 'assistant') and item.content.strip():
            messages.append({'role': item.role, 'content': item.content.strip()})
    messages.append({'role': 'user', 'content': message})

    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(
                'https://api.groq.com/openai/v1/chat/completions',
                headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'},
                json={
                    'model': os.getenv('OTAKUMIND_MODEL', 'llama-3.3-70b-versatile'),
                    'messages': messages,
                    'temperature': 0.8,
                    'max_tokens': 450,
                },
            )
    except httpx.TimeoutException as exc:
        print('OTAKUMIND: Groq timeout', flush=True)
        raise HTTPException(504, 'AI response timed out. Please try again.') from exc
    except httpx.RequestError as exc:
        print('OTAKUMIND: Groq connection error:', type(exc).__name__, flush=True)
        raise HTTPException(503, 'Cannot reach the AI provider right now.') from exc

    if response.status_code != 200:
        print('OTAKUMIND: Groq HTTP', response.status_code, response.text[:350], flush=True)
        if response.status_code in (401, 403):
            raise HTTPException(503, 'AI provider authentication failed. Check Render configuration.')
        if response.status_code == 429:
            raise HTTPException(429, 'AI provider rate limit reached. Please try again later.')
        raise HTTPException(503, f'AI provider returned HTTP {response.status_code}.')

    try:
        reply = response.json()['choices'][0]['message']['content'].strip()
        if not reply:
            raise ValueError('Empty AI response')
    except (ValueError, KeyError, IndexError, TypeError, AttributeError) as exc:
        print('OTAKUMIND: Invalid Groq response', flush=True)
        raise HTTPException(502, 'AI provider returned an invalid response.') from exc

    return {
        'personality_id': req.personality_id,
        'personality': profile['name'],
        'reply': reply[:1500],
        'voice': profile['voice'][req.language],
        'language': req.language,
    }

