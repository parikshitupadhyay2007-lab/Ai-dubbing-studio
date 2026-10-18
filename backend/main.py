import asyncio, json, os, shutil, subprocess, uuid, wave
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from faster_whisper import WhisperModel
import edge_tts
import httpx
ROOT = Path(__file__).parent / 'jobs'
ROOT.mkdir(exist_ok=True)

app = FastAPI(title='AI Dubbing Studio MVP')
model = None

VOICES = {
    'hi': {
        'natural': ['hi-IN-MadhurNeural', 'hi-IN-SwaraNeural'],
        'expressive': ['hi-IN-MadhurNeural', 'hi-IN-SwaraNeural']
    },
    'en': {
        'natural': [
            'en-US-GuyNeural',
            'en-US-JennyNeural',
            'en-US-AriaNeural'
        ],
        'expressive': [
            'en-US-ChristopherNeural',
            'en-US-AriaNeural',
            'en-US-DavisNeural'
        ]
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


@app.get('/health')
def health():
    return {'ok': True}

async def translate_dialogue(text: str, target: str, source: str = 'ja'):
    if not text.strip():
        return ''

    if source == target:
        return text

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(
                'https://api.mymemory.translated.net/get',
                params={
                    'q': text,
                    'langpair': f'{source}|{target}'
                }
            )

            response.raise_for_status()
            result = response.json()

            if result.get('responseStatus') != 200 or result.get('quotaFinished'):
                return ''

            return result.get('responseData', {}).get('translatedText', '')

    except (httpx.HTTPError, ValueError):
        return ''


@app.post('/projects')
async def create(file: UploadFile = File(...)):
    jid = uuid.uuid4().hex
    d = ROOT / jid
    d.mkdir()

    suffix = Path(file.filename or 'video.mp4').suffix.lower()

    if suffix not in (
        '.mp4', '.mov', '.mkv', '.webm',
        '.mp3', '.wav', '.m4a'
    ):
        raise HTTPException(400, 'Unsupported media format')

    source = d / ('source' + suffix)

    with source.open('wb') as f:
        while chunk := await file.read(1024 * 1024):
            f.write(chunk)

    if source.stat().st_size > 500 * 1024 * 1024:
        shutil.rmtree(d)
        raise HTTPException(413, '500 MB MVP limit')

    run(
        'ffmpeg', '-y',
        '-i', str(source),
        '-vn', '-ac', '1', '-ar', '16000',
        str(d / 'audio.wav')
    )

    # Use the smaller multilingual Whisper model.
    # Limit CPU concurrency to reduce resource usage.
    global model

    if model is None:
        model = WhisperModel(
            os.getenv('WHISPER_MODEL', 'tiny'),
            device='cpu',
            compute_type='int8',
            cpu_threads=1,
            num_workers=1,
        )

    segments, info = model.transcribe(
        str(d / 'audio.wav'),
        vad_filter=True
    )

    items = [
        {
            'id': i,
            'start': round(s.start, 2),
            'end': round(s.end, 2),
            'text': s.text.strip(),
            'speaker': 'Character 1',
            'translation': ''
        }
        for i, s in enumerate(segments)
    ]

    data = {
        'id': jid,
        'source': source.name,
        'source_language': info.language,
        'segments': items
    }

    (d / 'project.json').write_text(
        json.dumps(data, ensure_ascii=False)
    )

    return data


@app.get('/projects/{jid}')
def get_project(jid: str):
    return json.loads(
        (jobdir(jid) / 'project.json').read_text()
    )


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

    data = json.loads(
        (d / 'project.json').read_text()
    )

    if req.language not in VOICES or req.style not in (
        'natural', 'expressive'
    ):
        raise HTTPException(400, 'Invalid language/style')

    allowed = sum(VOICES[req.language].values(), [])

    for v in req.voices.values():
        if v not in allowed:
            raise HTTPException(
                400,
                'Voice does not match target language'
            )

    # The MVP uses user-edited translations.
    if any(not s.translation.strip() for s in req.segments):
        raise HTTPException(
            400,
            'Fill target-language text for every dialogue segment'
        )

    clips = []

    for i, s in enumerate(req.segments):
        voice = req.voices.get(s.speaker)

        if not voice:
            raise HTTPException(
                400,
                f'Assign a voice to {s.speaker}'
            )

        mp3 = d / f'clip{i}.mp3'
        wav = d / f'clip{i}.wav'

        rate = '+12%' if req.style == 'expressive' else '+0%'

        await edge_tts.Communicate(
            s.translation,
            voice,
            rate=rate
        ).save(str(mp3))

        run(
            'ffmpeg', '-y',
            '-i', str(mp3),
            '-ar', '24000',
            '-ac', '1',
            str(wav)
        )

        clips.append((s.start, wav))

    # Place generated dialogue clips on the timeline.
    import array

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

            mix[at] = max(
                -32768,
                min(32767, mix[at] + val)
            )

    with wave.open(str(d / 'dub.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(24000)
        f.writeframes(mix.tobytes())

    source = d / data['source']
    output = d / 'dubbed.mp4'

    # MVP: original audio is replaced.
    # Music and sound-effect preservation is a future feature.
    run(
        'ffmpeg', '-y',
        '-i', str(source),
        '-i', str(d / 'dub.wav'),
        '-map', '0:v:0?',
        '-map', '1:a:0',
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-c:a', 'aac',
        '-shortest',
        str(output)
    )

    return {
        'download_url': f'/projects/{jid}/download',
        'note': (
            'MVP replaces the original audio; '
            'no music/effects separation.'
        )
    }


@app.get('/projects/{jid}/download')
def download(jid: str):
    f = jobdir(jid) / 'dubbed.mp4'

    if not f.exists():
        raise HTTPException(
            404,
            'Render the project first'
        )

    return FileResponse(
        f,
        media_type='video/mp4',
        filename='AI-Dubbing-Studio.mp4'
    )
