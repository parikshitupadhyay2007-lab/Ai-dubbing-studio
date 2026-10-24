#!/usr/bin/env python3
"""Offline frame fingerprint matching for licensed reference frames.

Extract candidate frames with a locally installed FFmpeg, then compare dHash.
This is candidate retrieval only: visually similar animation frames are not
proof of anime, episode or character. Corpus rights must be validated separately.
"""
import argparse
import json
from pathlib import Path
from PIL import Image

def dhash(path):
    with Image.open(path) as im:
        im=im.convert("L").resize((9,8),Image.Resampling.LANCZOS)
        values=list(im.getdata())
    result=0
    for y in range(8):
        for x in range(8):
            result=(result<<1)|int(values[y*9+x]>values[y*9+x+1])
    return result

def retrieve(frame, catalog, root, max_distance=8):
    query=dhash(frame)
    results=[]
    for entry in catalog:
        relative=Path(entry["frame"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Invalid reference frame path")
        path=(root/relative).resolve()
        if not path.is_relative_to(root.resolve()):
            raise ValueError("Escaping catalog root")
        delta=(query^dhash(path)).bit_count()
        if delta<=max_distance:
            results.append({"anime_id":entry["anime_id"],
                "episode_id":entry["episode_id"],
                "time_seconds":entry["time_seconds"],
                "distance":delta})
    return sorted(results,key=lambda item:item["distance"])

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--frame",type=Path,required=True)
    p.add_argument("--reference-index",type=Path,required=True)
    p.add_argument("--reference-root",type=Path,required=True)
    p.add_argument("--max-distance",type=int,default=8)
    args=p.parse_args()
    if not 0<=args.max_distance<=64: raise ValueError("Invalid distance")
    catalog=json.loads(args.reference_index.read_text(encoding="utf-8"))
    print(json.dumps(retrieve(args.frame,catalog,args.reference_root,args.max_distance),indent=2))
if __name__=="__main__":main()
