#!/usr/bin/env python3
"""Evaluate human-reviewed dubbing translations without pretending lexical overlap
is semantic accuracy.

JSONL input, one object per line:
{"id":"scene-1","source":"...","reference":"...","candidate":"...",
 "meaning":0,"names":0,"tone":0,"naturalness":0,"reviewer":"reviewer-id"}
Each score is an integer from 0 (failed) to 4 (excellent). Source and
reference are mandatory; scores must come from a human bilingual reviewer.
Usage: python3 tools/evaluate_translation.py reviews.jsonl
"""
import argparse
import json
import statistics
import sys

DIMENSIONS = ("meaning", "names", "tone", "naturalness")


def evaluate(path):
    rows = []
    seen = set()
    with open(path, encoding="utf-8") as stream:
        for number, line in enumerate(stream, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
                if not isinstance(row, dict):
                    raise ValueError("expected JSON object")
                for field in ("id", "source", "reference", "candidate", "reviewer"):
                    if not isinstance(row.get(field), str) or not row[field].strip():
                        raise ValueError(f"missing {field}")
                if row["id"] in seen:
                    raise ValueError("duplicate id")
                for dimension in DIMENSIONS:
                    value = row.get(dimension)
                    if type(value) is not int or not 0 <= value <= 4:
                        raise ValueError(f"{dimension} must be integer 0..4")
                seen.add(row["id"])
                rows.append(row)
            except (ValueError, json.JSONDecodeError) as error:
                raise ValueError(f"Line {number}: {error}") from error
    if not rows:
        raise ValueError("No reviewed translation examples")
    report = {
        "reviewed_segments": len(rows),
        "mean_scores_out_of_4": {
            dimension: round(statistics.mean(r[dimension] for r in rows), 3)
            for dimension in DIMENSIONS
        },
        "critical_failures": [
            {"id": r["id"], "failed_dimensions": [
                d for d in ("meaning", "names") if r[d] < 3
            ]}
            for r in rows if r["meaning"] < 3 or r["names"] < 3
        ],
        "note": "Human-review results only; no automatic semantic accuracy claim.",
    }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reviews_jsonl")
    parser.add_argument("--fail-on-critical", action="store_true")
    args = parser.parse_args()
    try:
        report = evaluate(args.reviews_jsonl)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(json.dumps(report, indent=2, ensure_ascii=False))
    if args.fail_on_critical and report["critical_failures"]:
        sys.exit(2)


if __name__ == "__main__":
    main()
