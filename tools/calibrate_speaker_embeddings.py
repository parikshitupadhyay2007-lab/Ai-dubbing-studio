#!/usr/bin/env python3
"""Calibrate cosine-distance thresholds from labeled speaker embeddings.

Input JSON: [{"speaker_id":"A","embedding":[...]}, ...].
Use held-out, consented recordings representative of the target audio.
This tool does not train a model or establish its license.
"""
import argparse
import json
import math
from pathlib import Path


def normalize(vector):
    if not isinstance(vector, list) or not vector or any(
        not isinstance(x, (int, float)) or not math.isfinite(x) for x in vector
    ):
        raise ValueError("Embedding must be a nonempty finite numeric list")
    norm = math.sqrt(sum(x * x for x in vector))
    if not math.isfinite(norm) or norm <= 1e-12:
        raise ValueError("Embedding has invalid norm")
    return [x / norm for x in vector]


def calibrate(rows):
    if not isinstance(rows, list) or len(rows) < 4:
        raise ValueError("At least four labeled embeddings are required")
    vectors = []
    dims = None
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("speaker_id"), str) or not row["speaker_id"].strip():
            raise ValueError("Each row needs a nonempty speaker_id")
        v = normalize(row.get("embedding"))
        if dims is None:
            dims = len(v)
        if len(v) != dims:
            raise ValueError("Embedding dimensions must match")
        vectors.append((row["speaker_id"], v))
    same, different = [], []
    for i, (speaker, left) in enumerate(vectors):
        for other, right in vectors[i + 1:]:
            distance = 1.0 - max(-1.0, min(1.0, sum(a * b for a, b in zip(left, right))))
            (same if speaker == other else different).append(distance)
    if not same or not different:
        raise ValueError("Need both same-speaker and different-speaker pairs")
    # Minimize false matches first; unknown is safer than a wrong character voice.
    candidates = sorted(set([0.0, 2.0] + same + different))
    best = None
    for a, b in zip(candidates, candidates[1:]):
        threshold = (a + b) / 2
        false_accepts = sum(d < threshold for d in different)
        false_rejects = sum(d >= threshold for d in same)
        score = (false_accepts * 5 + false_rejects, false_accepts, false_rejects)
        if best is None or score < best[0]:
            best = (score, threshold)
    threshold = best[1]
    # A distinct new identity requires a wider separation than a match.
    # Report a candidate only; independent validation must confirm both cutoffs.
    new_threshold = min(2.0, threshold + 0.16)
    return {
        "embedding_dimension": dims,
        "same_speaker_pairs": len(same),
        "different_speaker_pairs": len(different),
        "candidate_match_threshold": round(threshold, 6),
        "candidate_new_speaker_threshold": round(new_threshold, 6),
        "false_accept_pairs": best[0][1],
        "false_reject_pairs": best[0][2],
        "warning": "Development-set estimates only. Validate on held-out speakers and recordings before enabling in app."
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("labeled_embeddings", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = calibrate(json.loads(args.labeled_embeddings.read_text(encoding="utf-8")))
    output = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(output, encoding="utf-8")
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
