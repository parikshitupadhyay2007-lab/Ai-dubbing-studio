#!/usr/bin/env python3
"""Reference-stem separation benchmark; PCM WAV inputs only, no external packages.

Usage:
 python3 tools/benchmark_separation.py --reference-vocals clean_voice.wav \
   --reference-background clean_background.wav --estimated-vocals vocals.wav \
   --estimated-background accompaniment.wav --max-leakage-db -15

Reference stems must be sample-aligned and their sum must represent the input
mixture. Scores are objective diagnostics, not perceptual listening scores.
"""
import argparse
import json
import math
import struct
import wave


def read_wav(path):
    with wave.open(path, "rb") as wav:
        rate, channels, width = wav.getframerate(), wav.getnchannels(), wav.getsampwidth()
        if width != 2 or channels not in (1, 2) or wav.getcomptype() != "NONE":
            raise ValueError(f"{path}: expected uncompressed mono/stereo 16-bit PCM WAV")
        frames = wav.getnframes()
        data = wav.readframes(frames)
    values = struct.unpack("<" + "h" * (len(data) // 2), data)
    return (rate, channels, frames), [v / 32768.0 for v in values]


def power(values):
    return sum(x * x for x in values)


def db_ratio(numerator, denominator):
    if denominator == 0:
        return None if numerator == 0 else float("inf")
    if numerator == 0:
        return float("-inf")
    return 10.0 * math.log10(numerator / denominator)


def projection_leakage(estimate, desired, interference):
    # Residual after projecting out desired source; then measure the part
    # correlated with the opposite reference. This is NOT a perceptual score.
    desired_energy = power(desired)
    opposite_energy = power(interference)
    if desired_energy <= 1e-12 or opposite_energy <= 1e-12:
        return None
    desired_gain = sum(a * b for a, b in zip(estimate, desired)) / desired_energy
    residual = [a - desired_gain * b for a, b in zip(estimate, desired)]
    opposite_gain = sum(a * b for a, b in zip(residual, interference)) / opposite_energy
    return db_ratio(opposite_gain * opposite_gain * opposite_energy, power(estimate))


def metrics(estimate, reference, opposite):
    reference_energy = power(reference)
    error_energy = sum((a - b) ** 2 for a, b in zip(estimate, reference))
    if reference_energy <= 1e-12:
        raise ValueError("Reference stem is silent; cannot calculate reference-relative metrics")
    dot = sum(a * b for a, b in zip(estimate, reference))
    estimate_energy = power(estimate)
    if estimate_energy <= 1e-12:
        si_sdr = None
    else:
        gain = dot / reference_energy
        target = gain * gain * reference_energy
        residual = sum((a - gain * b) ** 2 for a, b in zip(estimate, reference))
        si_sdr = db_ratio(target, residual)
    return {
        "sdr_db": db_ratio(reference_energy, error_energy),
        "si_sdr_db": si_sdr,
        "opposite_stem_projection_db": projection_leakage(estimate, reference, opposite),
        "peak_absolute": max((abs(v) for v in estimate), default=0.0),
        "clipped_sample_fraction": sum(abs(v) >= 32767 / 32768 for v in estimate) / len(estimate),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("reference-vocals", "reference-background", "estimated-vocals", "estimated-background"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--max-leakage-db", type=float, default=None,
                        help="Optional maximum opposite-stem projection in dB relative to output")
    args = parser.parse_args()
    paths = (args.reference_vocals, args.reference_background,
             args.estimated_vocals, args.estimated_background)
    loaded = [read_wav(p) for p in paths]
    specs = [item[0] for item in loaded]
    if any(spec != specs[0] for spec in specs[1:]):
        parser.error("All four files must have identical sample rate, channels and frame count; align them before benchmarking")
    if specs[0][2] == 0:
        parser.error("Empty WAV inputs are not valid benchmark material")
    voice, background, estimated_voice, estimated_background = [x[1] for x in loaded]
    report = {
        "sample_rate": specs[0][0], "channels": specs[0][1], "frames": specs[0][2],
        "vocals": metrics(estimated_voice, voice, background),
        "background": metrics(estimated_background, background, voice),
        "mixture_reconstruction_sdr_db": db_ratio(
            power([v + b for v, b in zip(voice, background)]),
            sum((v + b - ev - eb) ** 2 for v, b, ev, eb in
                zip(voice, background, estimated_voice, estimated_background))),
        "notes": "Reference-relative objective metrics; listening tests remain necessary.",
    }
    def safe(value):
        if isinstance(value, float) and not math.isfinite(value):
            return "Infinity" if value > 0 else "-Infinity"
        if isinstance(value, dict):
            return {k: safe(v) for k, v in value.items()}
        return value
    print(json.dumps(safe(report), indent=2, allow_nan=False))
    if args.max_leakage_db is not None:
        values = [report[key]["opposite_stem_projection_db"] for key in ("vocals", "background")]
        if any(value is None or value > args.max_leakage_db for value in values):
            raise SystemExit(2)


if __name__ == "__main__":
    main()
