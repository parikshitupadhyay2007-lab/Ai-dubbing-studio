"""Offline reference synthesizer for a prospective Supertonic-3 Android engine.

Install from the upstream archived MIT runtime; obtain the OpenRAIL-M weights
under their license. This is a runnable reference/batch renderer, not an Android
JNI implementation. Input JSON contains language, speaker_voices and segments.
No text is transmitted by this script; TTS(auto_download=False) requires
previously installed local assets.
"""
import argparse
import json
import math
from pathlib import Path

VOICE_NAMES = {*(f"M{x}" for x in range(1, 6)), *(f"F{x}" for x in range(1, 6))}
EXPRESSIONS = {"natural": "", "laugh": "<laugh>", "breath": "<breath>", "sigh": "<sigh>"}


def validate_plan(plan):
    language = plan.get("language")
    if language not in ("hi", "en"):
        raise ValueError("Only Hindi and English output is enabled")
    voices = plan.get("speaker_voices")
    if not isinstance(voices, dict) or not voices:
        raise ValueError("Nonempty speaker_voices mapping is required")
    if any(not isinstance(s, str) or v not in VOICE_NAMES for s, v in voices.items()):
        raise ValueError("Unknown speaker or built-in voice")
    segments = plan.get("segments")
    if not isinstance(segments, list) or not segments:
        raise ValueError("No dialogue segments")
    ids = set()
    for segment in segments:
        identifier = segment["id"]
        if not isinstance(identifier, int) or identifier in ids:
            raise ValueError("Segment IDs must be distinct integers")
        ids.add(identifier)
        if segment.get("speaker_id") not in voices:
            raise ValueError(f"Speaker not assigned: {identifier}")
        if not isinstance(segment.get("text"), str) or not segment["text"].strip():
            raise ValueError(f"Blank dialogue: {identifier}")
        if segment.get("expression", "natural") not in EXPRESSIONS:
            raise ValueError(f"Unsupported learned expression tag: {identifier}")
        start, end = segment["start"], segment["end"]
        if not all(isinstance(x, (float, int)) and math.isfinite(x) for x in (start, end)) or not 0 <= start < end:
            raise ValueError(f"Invalid dialogue timing: {identifier}")
    return language, voices, sorted(segments, key=lambda s: (s["start"], s["id"]))


def render(plan, output_directory, assets_directory):
    language, voices, segments = validate_plan(plan)
    from supertonic import TTS
    assets_directory = Path(assets_directory)\n    required = ("onnx/duration_predictor.onnx", "onnx/text_encoder.onnx",\n                "onnx/vector_estimator.onnx", "onnx/vocoder.onnx",\n                "onnx/tts.json", "onnx/unicode_indexer.json")\n    missing = [name for name in required if not (assets_directory / name).is_file()]\n    if missing:\n        raise FileNotFoundError("Incomplete Supertonic asset pack: " + ", ".join(missing))\n    tts = TTS(model="supertonic-3", model_dir=assets_directory, auto_download=False)
    output_directory = Path(output_directory)
    output_directory.mkdir(parents=True, exist_ok=True)
    styles = {voice: tts.get_voice_style(voice_name=voice) for voice in set(voices.values())}
    report = []
    for segment in segments:
        voice = voices[segment["speaker_id"]]
        expression = EXPRESSIONS[segment.get("expression", "natural")]
        text = f'{expression}{segment["text"]}' if expression else segment["text"]
        waveform, duration = tts.synthesize(text=text, voice_style=styles[voice],
            lang=language, total_steps=10, verbose=False)
        # Upstream returns a one-element NumPy duration array.
        duration_seconds = float(duration.item() if hasattr(duration, "item") else duration)
        if not math.isfinite(duration_seconds) or duration_seconds <= 0:
            raise RuntimeError(f'Invalid synthesis duration for {segment["id"]}')
        output = output_directory / f'segment_{segment["id"]}.wav'
        tts.save_audio(waveform, str(output))
        if not output.is_file() or output.stat().st_size <= 44:
            raise RuntimeError(f'Empty synthesized file for {segment["id"]}')
        report.append(dict(id=segment["id"], speaker_id=segment["speaker_id"],
            voice=voice, expression=segment.get("expression", "natural"),
            start=segment["start"], end=segment["end"], duration=duration_seconds,
            wav_path=str(output.resolve()),
            exceeds_window=duration_seconds > (segment["end"] - segment["start"]) * 1.12))
    (output_directory / "render_report.json").write_text(json.dumps(report, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("plan", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    render(json.loads(args.plan.read_text()), args.output_directory)
