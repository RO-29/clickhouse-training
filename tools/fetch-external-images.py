#!/usr/bin/env python3
"""Download every image listed in tools/external-images.json into
content/demo-assets/<module>/external/<sequence>-<name>.<ext>.

Idempotent: skips files that already exist on disk with non-zero size.
"""
import json, hashlib, sys, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "content" / "demo-assets"
SPEC = ROOT / "tools" / "external-images.json"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:129.0) Gecko/20100101 Firefox/129.0"

def slug_for(url: str, idx: int) -> str:
    name = url.rsplit("/", 1)[-1]
    # Strip CDN hash suffix on docs assets like 'foo-3e6fd5aa48e3075202d242b4799da8fa.gif'
    if "." in name:
        stem, ext = name.rsplit(".", 1)
        # Trim trailing 32-char hex hash if present
        if "-" in stem and len(stem.split("-")[-1]) == 32:
            stem = "-".join(stem.split("-")[:-1])
        return f"{idx:02d}-{stem}.{ext.lower()}"
    return f"{idx:02d}-img"

def fetch(url: str, dest: Path) -> bool:
    if dest.exists() and dest.stat().st_size > 0:
        return False  # already present
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = r.read()
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
        print(f"  ✗ {url} → {e}")
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return True

def main():
    spec = json.loads(SPEC.read_text())
    total, fetched, skipped = 0, 0, 0
    for module, items in spec.items():
        out_dir = ASSETS / module / "external"
        for i, (url, caption, src_url, src_name) in enumerate(items, 1):
            total += 1
            dest = out_dir / slug_for(url, i)
            print(f"  {module}/{dest.name}")
            if fetch(url, dest):
                fetched += 1
            else:
                skipped += 1
    print(f"\n{fetched} downloaded, {skipped} skipped/failed, {total} total")

if __name__ == "__main__":
    sys.exit(main() or 0)
