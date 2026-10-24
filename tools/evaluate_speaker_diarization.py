#!/usr/bin/env python3
"""Evaluate speaker identities against independently annotated dialogue.

JSONL rows: {"id":"scene:segment","reference_speaker":"character_a",
"predicted_speaker":"speaker_1","overlap":false}. Use "unknown" for
unresolved predictions. IDs are local to a scene; mapping is one-to-one
and is fitted on the same evaluation scene, not evidence of generalization.
A predicted cluster may map to at most one reference character.
"""
import argparse
import collections
import json
import sys


def evaluate(path):
    scenes = collections.defaultdict(list)
    seen = set()
    with open(path, encoding="utf-8") as stream:
        for number, line in enumerate(stream, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
                if not isinstance(row, dict):
                    raise ValueError("expected object")
                for key in ("id", "reference_speaker", "predicted_speaker"):
                    if not isinstance(row.get(key), str) or not row[key].strip():
                        raise ValueError("missing " + key)
                if type(row.get("overlap")) is not bool:
                    raise ValueError("overlap must be boolean")
                if row["id"] in seen:
                    raise ValueError("duplicate id")
                seen.add(row["id"])
                scene = row["id"].split(":", 1)[0]
                if ":" not in row["id"] or not scene:
                    raise ValueError("id must be scene:segment")
                scenes[scene].append(row)
            except (ValueError, json.JSONDecodeError) as error:
                raise ValueError(f"Line {number}: {error}") from error
    if not scenes:
        raise ValueError("No annotated segments")
    total = correct = unresolved = overlap_count = 0
    for rows in scenes.values():
        # Majority mapping is diagnostic; collisions are never counted as
        # separate successful character identities.
        votes = collections.defaultdict(collections.Counter)
        for row in rows:
            if not row["overlap"] and row["predicted_speaker"] != "unknown":
                votes[row["predicted_speaker"]][row["reference_speaker"]] += 1
        candidates = sorted(
            ((count, cluster, ref) for cluster, counts in votes.items()
             for ref, count in counts.items()), reverse=True
        )
        mapping = {}
        assigned = set()
        for _, cluster, ref in candidates:
            if cluster not in mapping and ref not in assigned:
                mapping[cluster] = ref
                assigned.add(ref)
        for row in rows:
            total += 1
            overlap_count += int(row["overlap"])
            if row["predicted_speaker"] == "unknown":
                unresolved += 1
            elif not row["overlap"] and mapping.get(row["predicted_speaker"]) == row["reference_speaker"]:
                correct += 1
    return {
        "segments": total, "scenes": len(scenes),
        "correct_nonoverlap": correct, "unresolved": unresolved,
        "overlap_segments": overlap_count,
        "conservative_accuracy": round(correct / total, 4),
        "note": "Includes unknown and overlap in denominator; cluster mapping fitted per scene. Human-annotated evaluation only."
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("annotations_jsonl")
    parser.add_argument("--production-gate", action="store_true")
    args = parser.parse_args()
    try:
        report = evaluate(args.annotations_jsonl)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(json.dumps(report, indent=2))
    if args.production_gate and (report["segments"] < 200 or
                                 report["conservative_accuracy"] < 0.98 or
                                 report["unresolved"] > 0):
        print("Speaker identity production gate failed.", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
