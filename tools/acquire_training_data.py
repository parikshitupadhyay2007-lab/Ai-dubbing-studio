#!/usr/bin/env python3
"""Explicit, local-only acquisition of rights-reviewed datasets.

No downloads at import, no bypass of credential gates, no GitHub artifact
uploads. Registry entries other than public_direct are never auto-fetched.
"""
import argparse
import hashlib
import json
import urllib.request
from pathlib import Path

def load_registry(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != 1: raise ValueError("Unsupported registry schema")
    entries = {row["id"]:row for row in data["datasets"]}
    if len(entries) != len(data["datasets"]): raise ValueError("Duplicate IDs")
    return entries

def acquire(item, destination, acknowledge):
    if item["status"] != "public_direct":
        raise ValueError("This source needs manual access or documented permission; see registry.")
    if not acknowledge: raise ValueError("Read and acknowledge source terms before download.")
    url = item["url"]
    if not url.startswith("https://www.openslr.org/resources/12/"):
        raise ValueError("Unexpected download host; refusing unreviewed URL")
    destination.mkdir(parents=True, exist_ok=True)
    path=destination / (item["id"]+".tar.gz")
    tmp=path.with_suffix(".partial")
    digest=hashlib.sha256()
    try:
        with urllib.request.urlopen(url,timeout=60) as source, tmp.open("wb") as output:
            while True:
                chunk=source.read(1024*1024)
                if not chunk: break
                output.write(chunk)
                digest.update(chunk)
        if not tmp.stat().st_size: raise ValueError("Empty download")
        tmp.replace(path)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise
    receipt={"id":item["id"],"source":url,"license":item["license"],
             "size_bytes":path.stat().st_size,"sha256":digest.hexdigest(),
             "path":str(path),"note":"Download receipt is not a quality or rights audit."}
    (destination/(item["id"]+".receipt.json")).write_text(
        json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    return receipt

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--registry",type=Path,default=Path("datasets/acquisition_registry.json"))
    p.add_argument("--list",action="store_true")
    p.add_argument("--id")
    p.add_argument("--destination",type=Path,default=Path("private_datasets"))
    p.add_argument("--accept-source-terms",action="store_true")
    args=p.parse_args()
    registry=load_registry(args.registry)
    if args.list:
        for item in registry.values():
            print(item["id"],item["status"],item["url"] or "locally sourced")
        return
    if not args.id or args.id not in registry: p.error("Specify a known --id or --list")
    print(json.dumps(acquire(registry[args.id],args.destination,
                             args.accept_source_terms),indent=2))
if __name__=="__main__":main()
