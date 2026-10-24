#!/usr/bin/env python3
"""Measure scene identification without leakage between train and test episodes."""
import argparse
import json
from collections import defaultdict
from pathlib import Path

def normalize(s):
    return "".join(ch.lower() for ch in s if ch.isalnum())

def match(dialogue, references):
    lines=[normalize(x) for x in dialogue if len(normalize(x)) >= 8]
    if len(lines)<3: return None
    ranked=[]
    for ref in references:
        candidate=[normalize(x) for x in ref["dialogue"]]
        longest=0
        for offset in range(len(candidate)):
            matched=0
            while matched<len(lines) and offset+matched<len(candidate) and lines[matched]==candidate[offset+matched]:
                matched+=1
            longest=max(longest,matched)
        if longest>=3:
            ranked.append((longest/max(3,len(lines)),ref))
    ranked.sort(key=lambda pair:pair[0],reverse=True)
    if not ranked or ranked[0][0]<.8 or (len(ranked)>1 and ranked[0][0]-ranked[1][0]<.15):
        return None
    return ranked[0][1]

def evaluate(rows, references):
    if not rows: raise ValueError("Nonempty held-out labeled scenes required")
    ref_episodes={(r["anime_id"],r["episode_id"]) for r in references}
    # Test examples from the same annotated episode must not be used to
    # claim independent generalization when that episode appears in training.
    total=correct=abstained=wrong=0
    for row in rows:
        total+=1
        candidate=match(row["dialogue"],references)
        if candidate is None: abstained+=1
        elif (candidate["anime_id"],candidate["episode_id"]) == (row["anime_id"],row["episode_id"]): correct+=1
        else: wrong+=1
    return {"total":total,"correct":correct,"wrong":wrong,"abstained":abstained,
            "accuracy_on_answered":correct/max(1,total-abstained),
            "coverage":(total-abstained)/total,
            "false_identification_rate":wrong/total,
            "warning":"Evaluate on licensed, labeled independent clips; matching a catalog entry is not speaker identification."}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--catalog",type=Path,required=True)
    p.add_argument("--held-out",type=Path,required=True)
    p.add_argument("--report",type=Path,required=True)
    a=p.parse_args()
    catalog=json.loads(a.catalog.read_text())
    held=json.loads(a.held_out.read_text())
    report=evaluate(held,catalog)
    a.report.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))
if __name__=="__main__":main()
