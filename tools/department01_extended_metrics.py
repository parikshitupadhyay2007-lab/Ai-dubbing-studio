"""Additional independently annotated Department 01 quality measurements.

Diagnostic only. Scores never grant professional acceptance or substitute for
specialist model receipts, lawful footage or physical-device validation.
"""
import math


def _records(rows, key):
    if not isinstance(rows, list) or not rows:
        raise ValueError("Missing independently annotated records")
    result = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get(key), str) or not row[key] or row[key] in result:
            raise ValueError("Missing or duplicate annotation identity")
        result[row[key]] = row
    return result


def measure(reference, prediction):
    if reference.get("source_sha256") != prediction.get("source_sha256"):
        raise ValueError("Reference/prediction source fingerprint mismatch")
    expected = _records(reference.get("character_observations"), "observation_id")
    actual = _records(prediction.get("character_observations"), "observation_id")
    if set(actual) != set(expected):
        raise ValueError("Character observation coverage mismatch")
    total = len(expected)
    known = 0
    correct = 0
    abstained = 0
    for key, truth in expected.items():
        label = truth.get("character_id")
        guessed = actual[key].get("character_id", "unknown")
        if not isinstance(label, str) or not label or not isinstance(guessed, str):
            raise ValueError("Invalid character identity")
        if label != "unknown":
            known += 1
            correct += int(guessed == label)
        abstained += int(guessed == "unknown")
    episodes = _records(reference.get("episode_cases"), "case_id")
    ep_predictions = _records(prediction.get("episode_cases"), "case_id")
    if set(episodes) != set(ep_predictions):
        raise ValueError("Episode evaluation coverage mismatch")
    unknown_total = 0
    unknown_rejected = 0
    known_total = 0
    known_correct = 0
    for key, truth in episodes.items():
        target = truth.get("episode_id")
        guessed = ep_predictions[key].get("episode_id", "unknown")
        if not isinstance(target, str) or not target or not isinstance(guessed, str):
            raise ValueError("Invalid episode identity")
        if target == "unknown":
            unknown_total += 1
            unknown_rejected += int(guessed == "unknown")
        else:
            known_total += 1
            known_correct += int(guessed == target)
    timing = _records(reference.get("dialogue_timing"), "utterance_id")
    timing_prediction = _records(prediction.get("dialogue_timing"), "utterance_id")
    if set(timing) != set(timing_prediction):
        raise ValueError("Dialogue timing coverage mismatch")
    errors = []
    for key, truth in timing.items():
        observed = timing_prediction[key]
        for record in (truth, observed):
            if not all(isinstance(record.get(k), int) and not isinstance(record[k], bool)
                       for k in ("start_ms", "end_ms")) or record["start_ms"] < 0 or record["end_ms"] <= record["start_ms"]:
                raise ValueError("Invalid utterance timing")
        errors.extend((abs(observed[k] - truth[k]) for k in ("start_ms", "end_ms")))
    conflicts = prediction.get("unresolved_continuity_conflicts")
    if not isinstance(conflicts, list) or any(not isinstance(x, str) or not x for x in conflicts):
        raise ValueError("Missing continuity conflict audit")
    metrics = {
        "character_accuracy_known": correct / known if known else None,
        "character_abstention_rate": abstained / total,
        "episode_accuracy_known": known_correct / known_total if known_total else None,
        "episode_unknown_recall": unknown_rejected / unknown_total if unknown_total else None,
        "dialogue_boundary_mae_ms": sum(errors) / len(errors),
        "unresolved_continuity_conflicts": len(conflicts),
        "character_observations": total,
        "episode_cases": len(episodes),
        "timed_utterances": len(timing),
    }
    for value in metrics.values():
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError("Nonfinite benchmark")
    return {"certification": "diagnostic_only", "passed": False, "metrics": metrics,
            "requires": ["held_out_provenance", "model_receipts", "independent_review",
                         "physical_android_validation", "eleven_capability_gate"]}
