#!/usr/bin/env python3
"""Validate consented/licensed anime-scene references before publication.

Input JSON object: {"schema":1,"license":...,"source":...,"scenes":[...]}.
Only records with explicit redistribution permission may be exported. Do not
scrape subtitles, frames, or copyrighted scripts from arbitrary websites.
"""
import argparse
import json
import math
from pathlib import Path

ALLOWED = {"CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0", "OWNED", "EXPLICIT-PERMISSION"}
REQUIRED = {"anime_id", "title", "episode_id", "start_seconds", "dialogue", "characters"}
def validate(document):
    if document.get("schema") != 1 or document.get("license") not in ALLOWED:
        raise ValueError("Dataset schema or redistribution license is unapproved")
    if not document.get("source") or not document.get("evidence"):
        raise ValueError("Source and rights evidence required")
    scenes = document.get("scenes")
    if not isinstance(scenes, list): raise ValueError("scenes must be a list")
    ids = set()
    result = []
    for row in scenes:
        if not isinstance(row, dict) or not REQUIRED.issubset(row):
            raise ValueError("Incomplete scene record")
        key = (row["anime_id"], row["episode_id"], row["start_seconds"])
        if key in ids: raise ValueError("Duplicate scene")
        ids.add(key)
        if any(not isinstance(row[k], str) or not row[k].strip()
               for k in ("anime_id", "title", "episode_id")):
            raise ValueError("Empty anime/episode identity")
        start = row["start_seconds"]
        if not isinstance(start, (int,float)) or not math.isfinite(start) or start < 0:
            raise ValueError("Invalid scene timestamp")
        lines = row["dialogue"]
        if not isinstance(lines,list) or len(lines) < 3 or any(
            not isinstance(line,str) or len(line.strip()) < 8 for line in lines):
            raise ValueError("Three substantial transcript lines required")
        characters = row["characters"]
        if not isinstance(characters,list): raise ValueError("characters must be a list")
        names = set()
        for character in characters:
            if not isinstance(character,dict) or not all(
                isinstance(character.get(k),str) and character[k].strip()
                for k in ("id","name")):
                raise ValueError("Invalid character metadata")
            if character["id"] in names: raise ValueError("Duplicate character ID")
            names.add(character["id"])
            if character.get("role") not in ("unknown","male","female","youthful"):
                raise ValueError("Role must be annotated, not inferred from name")
        result.append({k:row[k] for k in sorted(REQUIRED)})
    return result

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("dataset",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    doc=json.loads(args.dataset.read_text(encoding="utf-8"))
    data=validate(doc)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Validated {len(data)} licensed anime scene references")
if __name__=="__main__": main()
