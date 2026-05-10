#!/usr/bin/env python3
"""Create or update a GitHub Gist per module containing the demo's runnable
files (setup.sql, data.sql, queries.sql, extras.sql, run.sh, configs, etc.)
and persist the gist URL/ID under tools/notion-gists.json.

Re-running this script:
  - if a gist for a module already exists in notion-gists.json → updates it
    (gh gist edit <id> -a <new-files>)  — keeps the same URL/permalink
  - otherwise → creates a fresh gist (gh gist create) and records its URL/ID

Authentication: uses your `gh` CLI session (gh auth status).

Output JSON shape:
{
  "module-1-fundamentals": {
    "id":  "abc123...",
    "url": "https://gist.github.com/<user>/<id>",
    "files": ["README.md", "setup.sql", ...]
  },
  ...
}

Usage:
  python3 tools/manage-gists.py             # all modules
  python3 tools/manage-gists.py 3 6         # just modules 3 and 6
  python3 tools/manage-gists.py --recreate  # delete + recreate everything
"""
from __future__ import annotations

import json
import subprocess
import sys
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEMOS = ROOT / "code-examples" / "demos"
TRACK = ROOT / "tools" / "notion-gists.json"

MODULE_DIRS = {
    1: "module-1-fundamentals",
    2: "module-2-table-engines",
    3: "module-3-sharding",
    4: "module-4-replication",
    5: "module-5-cluster-deploy",
    6: "module-6-query-opt",
    7: "module-7-backup",
    8: "module-8-dr",
    9: "module-9-kafka",
}

# Files we include in every gist, in this order.
def gist_files(folder: Path) -> list[Path]:
    """Return the list of demo files to include in the gist for `folder`,
    in display order (Gist sorts alphabetically anyway, but we name them
    so the natural ordering reads top-down)."""
    out: list[Path] = []
    # README first — Gist renders it as the description page
    rd = folder / "README.md"
    if rd.exists(): out.append(rd)

    # Lifecycle scripts (small + central)
    for n in ["docker-compose.yml", "up.sh", "run.sh", "down.sh"]:
        p = folder / n
        if p.exists(): out.append(p)

    # The actual content
    for n in ["setup.sql", "data.sql", "data.py", "produce.py",
              "queries.sql", "queries-s3.sql", "extras.sql"]:
        p = folder / n
        if p.exists(): out.append(p)

    # Configs
    cfg = folder / "configs"
    if cfg.exists():
        for p in sorted(cfg.rglob("*")):
            if p.is_file() and p.suffix in (".xml", ".yml", ".yaml"):
                out.append(p)

    return out


def staged_dir_for(folder: Path) -> Path:
    """Stage files into a flat tmp dir with module-prefixed names so the
    gist's file list is unambiguous and globally unique."""
    tmp = Path("/tmp") / f"gist-stage-{folder.name}"
    if tmp.exists(): shutil.rmtree(tmp)
    tmp.mkdir(parents=True)
    prefix = folder.name
    for p in gist_files(folder):
        rel = p.relative_to(folder)
        # Flatten "configs/foo.xml" → "configs--foo.xml" so gist's flat
        # namespace is readable and we never collide.
        flat = str(rel).replace("/", "--")
        # Special-case the README so Gist picks it as the landing file
        if rel.name == "README.md":
            target = tmp / "README.md"   # gist convention: top-level README
        else:
            target = tmp / f"{prefix}--{flat}"
        shutil.copy2(p, target)
    return tmp


def gh(*args, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(["gh", *args], capture_output=True, text=True,
                          check=False, **kwargs)


def gist_create(folder: Path, public: bool = False) -> tuple[str, str]:
    tmp = staged_dir_for(folder)
    paths = sorted(p for p in tmp.iterdir() if p.is_file())
    desc = (
        f"ClickHouse training — {folder.name} hands-on Docker demo. "
        "Self-contained: ./up.sh && ./run.sh && ./down.sh."
    )
    args = ["gist", "create", *map(str, paths), "--desc", desc]
    if public: args.append("--public")
    r = gh(*args)
    if r.returncode != 0:
        raise RuntimeError(f"gh gist create failed: {r.stderr.strip()}")
    url = r.stdout.strip().splitlines()[-1].strip()
    gist_id = url.rsplit("/", 1)[-1]
    return gist_id, url


def gist_update(gist_id: str, folder: Path) -> None:
    """Replace every file in the gist with the latest from disk.

    `gh gist edit <id> -a <file>` adds/replaces a single file but doesn't
    remove files that are no longer present. To keep things simple we
    use `gh api` directly with the full PATCH payload.
    """
    tmp = staged_dir_for(folder)
    paths = sorted(p for p in tmp.iterdir() if p.is_file())

    # Build the PATCH body for /gists/<id>: { files: { "<name>": {"content": ...} } }
    files_payload = {}
    for p in paths:
        files_payload[p.name] = {"content": p.read_text(errors="replace")}

    desc = (
        f"ClickHouse training — {folder.name} hands-on Docker demo. "
        "Self-contained: ./up.sh && ./run.sh && ./down.sh."
    )
    body = json.dumps({"description": desc, "files": files_payload})

    r = subprocess.run(
        ["gh", "api", "-X", "PATCH", f"gists/{gist_id}", "--input", "-"],
        input=body, capture_output=True, text=True, check=False,
    )
    if r.returncode != 0:
        raise RuntimeError(f"gh api PATCH gists/{gist_id} failed: {r.stderr.strip()}")


def gist_delete(gist_id: str) -> None:
    r = gh("gist", "delete", gist_id, "--yes")
    if r.returncode != 0:
        # 404 is fine (already deleted)
        if "Not Found" in r.stderr or "404" in r.stderr:
            return
        raise RuntimeError(f"gh gist delete {gist_id} failed: {r.stderr.strip()}")


def load_track() -> dict:
    if TRACK.exists():
        return json.loads(TRACK.read_text())
    return {}


def save_track(d: dict) -> None:
    TRACK.write_text(json.dumps(d, indent=2, sort_keys=True) + "\n")


def main() -> int:
    args = sys.argv[1:]
    recreate = "--recreate" in args
    args = [a for a in args if not a.startswith("--")]
    requested = [int(x) for x in args] if args else sorted(MODULE_DIRS)

    track = load_track()

    for n in requested:
        name = MODULE_DIRS.get(n)
        if not name:
            print(f"  ✗ module {n}: unknown"); continue
        folder = DEMOS / name
        if not folder.exists():
            print(f"  ✗ module {n}: demo folder missing"); continue

        print(f"  module {n} ({name}):")
        existing = track.get(name)
        try:
            if recreate and existing:
                print(f"    deleting prior gist {existing['id']}")
                gist_delete(existing["id"])
                existing = None

            if existing:
                print(f"    updating {existing['url']}")
                gist_update(existing["id"], folder)
                # File list may have changed
                staged = staged_dir_for(folder)
                track[name]["files"] = sorted(p.name for p in staged.iterdir() if p.is_file())
                track[name]["url"] = existing["url"]
            else:
                gist_id, url = gist_create(folder)
                staged = staged_dir_for(folder)
                track[name] = {
                    "id": gist_id,
                    "url": url,
                    "files": sorted(p.name for p in staged.iterdir() if p.is_file()),
                }
                print(f"    ✓ created {url}")
        except Exception as e:
            print(f"    ✗ {type(e).__name__}: {e}")
            continue

    save_track(track)
    print(f"\nTracking saved to {TRACK.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
