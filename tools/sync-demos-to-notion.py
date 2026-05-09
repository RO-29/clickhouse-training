#!/usr/bin/env python3
"""
Sync the per-module Docker demos under code-examples/demos/module-N-*/ into
Notion as **child pages** of each module's existing Notion page.

What it does, per module:
  1. Locate the existing module page (from `tools/notion-page-ids.json`).
  2. If a child page titled "🐳 Hands-on Docker Demo" exists, archive it
     (so we always upsert a fresh copy).
  3. Create a new child page with:
        • a 1-line summary
        • a "Run locally" code block (cd / up.sh / run.sh)
        • bullet list of links (GitHub README, demo folder, every file)
        • the module's setup.sql / data.sql / queries.sql / extras.sql as
          syntax-highlighted code blocks (chunked to fit Notion's 2000-char
          rich_text limit).
  4. Optionally: append a single bookmark link to the same demo on the
     parent page so it's visible without expanding.

Usage:
  export NOTION_API_KEY=secret_xxx
  python3 tools/sync-demos-to-notion.py            # sync all modules
  python3 tools/sync-demos-to-notion.py 3 6        # only modules 3 and 6

Notion-page-ids.json shape (one entry per module):
{
  "1": "1a2b3c4d-...-...-...",
  "2": "...",
  ...
}

Pure stdlib + requests. No markdown→blocks conversion (the GitHub link
already renders the README beautifully); we push the *runnable code* into
Notion which is what teammates will copy-paste from.
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import requests

NOTION_API_KEY = os.environ.get("NOTION_API_KEY", "")
NOTION_VERSION = "2022-06-28"
BASE = "https://api.notion.com/v1"

ROOT = Path(__file__).resolve().parent.parent
DEMOS = ROOT / "code-examples" / "demos"
PAGE_IDS_FILE = ROOT / "tools" / "notion-page-ids.json"

# Module N → demo folder name
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

CHILD_TITLE = "🐳 Hands-on Docker Demo"
RICH_TEXT_MAX = 2000  # Notion API limit per rich_text content chunk
CODE_LANG = {".sql": "sql", ".py": "python", ".sh": "bash", ".yml": "yaml", ".xml": "markup"}


def headers() -> dict:
    if not NOTION_API_KEY:
        sys.exit("NOTION_API_KEY env var is required.")
    return {
        "Authorization": f"Bearer {NOTION_API_KEY}",
        "Content-Type": "application/json",
        "Notion-Version": NOTION_VERSION,
    }


def load_page_ids() -> dict:
    if not PAGE_IDS_FILE.exists():
        sys.exit(
            f"Missing {PAGE_IDS_FILE}.\n\n"
            "Create it with one entry per module, mapping module number → "
            "Notion page ID:\n"
            '  { "1": "<page-id>", "2": "<page-id>", ... }\n\n'
            "Get a page ID by opening the page in Notion and copying the "
            "32-char hex from the URL."
        )
    return json.loads(PAGE_IDS_FILE.read_text())


def chunk(text: str, n: int = RICH_TEXT_MAX) -> list[str]:
    """Split text into <=n-char pieces, breaking on newlines when possible."""
    if len(text) <= n:
        return [text]
    out, buf = [], ""
    for line in text.splitlines(keepends=True):
        if len(buf) + len(line) > n:
            if buf:
                out.append(buf)
                buf = ""
            # Single very long line — hard split
            while len(line) > n:
                out.append(line[:n])
                line = line[n:]
        buf += line
    if buf:
        out.append(buf)
    return out


def code_block(content: str, language: str) -> list[dict]:
    """Return one or more Notion code blocks for the given content."""
    blocks = []
    for piece in chunk(content):
        blocks.append({
            "object": "block",
            "type": "code",
            "code": {
                "language": language,
                "rich_text": [{"type": "text", "text": {"content": piece}}],
            },
        })
    return blocks


def heading(level: int, text: str) -> dict:
    key = {1: "heading_1", 2: "heading_2", 3: "heading_3"}[level]
    return {
        "object": "block",
        "type": key,
        key: {"rich_text": [{"type": "text", "text": {"content": text}}]},
    }


def paragraph(text: str) -> dict:
    return {
        "object": "block",
        "type": "paragraph",
        "paragraph": {"rich_text": [{"type": "text", "text": {"content": text}}]},
    }


def divider() -> dict:
    return {"object": "block", "type": "divider", "divider": {}}


def list_existing_children(parent_id: str) -> list[dict]:
    """Return all blocks under parent_id (flat — one page deep)."""
    results, cursor = [], None
    while True:
        params = {"page_size": 100}
        if cursor:
            params["start_cursor"] = cursor
        r = requests.get(f"{BASE}/blocks/{parent_id}/children",
                         headers=headers(), params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
        results.extend(data["results"])
        if not data.get("has_more"):
            break
        cursor = data.get("next_cursor")
    return results


def archive_existing_demo_child(parent_id: str) -> int:
    """Archive any prior 'Hands-on Docker Demo' child page so we can upsert."""
    archived = 0
    for blk in list_existing_children(parent_id):
        if blk.get("type") != "child_page":
            continue
        title = blk.get("child_page", {}).get("title", "")
        if title.strip() == CHILD_TITLE:
            r = requests.patch(f"{BASE}/pages/{blk['id']}",
                               headers=headers(),
                               json={"archived": True}, timeout=30)
            if r.ok:
                archived += 1
    return archived


def bullet(text: str) -> dict:
    return {
        "object": "block",
        "type": "bulleted_list_item",
        "bulleted_list_item": {
            "rich_text": [{"type": "text", "text": {"content": text}}]
        },
    }


def build_demo_blocks(folder: Path) -> list[dict]:
    blocks: list[dict] = []

    blocks.append(paragraph(
        "Self-contained ClickHouse stack you can run locally with Docker. "
        "Files are reproduced below as code blocks for easy copy-paste; the "
        "live source lives in the repo at the path shown under 'Run locally'."
    ))

    diag_dir = folder / "diagrams"
    if diag_dir.exists():
        anim_count = sum(1 for f in diag_dir.glob("anim-*.svg"))
        diag_count = sum(1 for f in diag_dir.glob("[0-9]*.svg"))
        gif = diag_dir / "demo.gif"
        bits = []
        if gif.exists():
            bits.append("a GIF capture of `./run.sh`")
        if anim_count:
            bits.append(f"{anim_count} animated SVG concept diagram(s)")
        if diag_count:
            bits.append(f"{diag_count} architecture diagram(s) rendered from the README's Mermaid sources")
        if bits:
            blocks.append(paragraph(
                "Visuals (in the repo at code-examples/demos/" + folder.name +
                "/diagrams/, also embedded into the corresponding HTML page on the training site): "
                + "; ".join(bits) + "."
            ))

    blocks.append(heading(2, "🚀 Run locally"))
    blocks.extend(code_block(
        f"cd code-examples/demos/{folder.name}\n"
        "./up.sh        # bring stack up, wait for health\n"
        "./run.sh       # run the demo (idempotent — re-runnable)\n"
        "./down.sh      # tear down + drop volumes\n",
        "bash",
    ))

    blocks.append(heading(2, "📁 Files in this demo"))
    for child in sorted(folder.iterdir()):
        if child.is_file() and child.suffix in (".sql", ".py", ".sh", ".yml", ".xml", ".md"):
            blocks.append(bullet(child.name))
    # Surface configs/* if present
    for sub in sorted(folder.rglob("configs/*")):
        if sub.is_file():
            blocks.append(bullet(str(sub.relative_to(folder))))

    blocks.append(divider())
    blocks.append(heading(2, "📋 Source files"))

    # Order matters — readers want setup → data → queries → extras.
    file_order = ["setup.sql", "data.sql", "data.py", "produce.py",
                  "queries.sql", "queries-s3.sql", "extras.sql"]
    seen = set()
    for name in file_order:
        path = folder / name
        if path.exists():
            seen.add(name)
            blocks.append(heading(3, name))
            lang = CODE_LANG.get(path.suffix, "plain text")
            blocks.extend(code_block(path.read_text(), lang))

    # Anything else worth including (run.sh shows what executes; configs/*.xml).
    for path in sorted(folder.rglob("*")):
        if not path.is_file() or path.name in seen:
            continue
        if path.suffix not in (".sh", ".xml"):
            continue
        if path.name in {"up.sh", "down.sh"}:
            continue
        rel = path.relative_to(folder)
        blocks.append(heading(3, str(rel)))
        lang = CODE_LANG.get(path.suffix, "plain text")
        blocks.extend(code_block(path.read_text(), lang))

    return blocks


def create_demo_child(parent_id: str, folder: Path) -> str:
    """Create a child page titled CHILD_TITLE under parent_id. Returns the new page URL."""
    blocks = build_demo_blocks(folder)

    # Notion limits a single create-page call to 100 children. We create the
    # page with the first 100 blocks, then append the rest.
    payload = {
        "parent": {"page_id": parent_id},
        "properties": {
            "title": [{"type": "text", "text": {"content": CHILD_TITLE}}]
        },
        "children": blocks[:100],
    }
    r = requests.post(f"{BASE}/pages", headers=headers(), json=payload, timeout=30)
    r.raise_for_status()
    new_page = r.json()
    new_page_id = new_page["id"]
    new_page_url = new_page["url"]

    rest = blocks[100:]
    while rest:
        batch, rest = rest[:100], rest[100:]
        rr = requests.patch(f"{BASE}/blocks/{new_page_id}/children",
                            headers=headers(), json={"children": batch}, timeout=30)
        rr.raise_for_status()
        time.sleep(0.2)  # mild rate-limit politeness

    return new_page_url


def sync_module(num: int, parent_page_id: str) -> None:
    folder_name = MODULE_DIRS.get(num)
    if not folder_name:
        print(f"  module {num}: no demo (skipping)")
        return
    folder = DEMOS / folder_name
    if not folder.exists():
        print(f"  module {num}: folder missing ({folder}) (skipping)")
        return

    print(f"  module {num} ({folder_name}):")
    archived = archive_existing_demo_child(parent_page_id)
    if archived:
        print(f"    archived {archived} prior demo child page(s)")
    new_url = create_demo_child(parent_page_id, folder)
    print(f"    ✓ {new_url}")


def main() -> int:
    page_ids = load_page_ids()
    requested = [int(x) for x in sys.argv[1:]] if len(sys.argv) > 1 else sorted(MODULE_DIRS)
    print(f"Syncing modules: {requested}")
    for n in requested:
        page_id = page_ids.get(str(n))
        if not page_id:
            print(f"  module {n}: missing page id in {PAGE_IDS_FILE.name} (skipping)")
            continue
        try:
            sync_module(n, page_id)
        except requests.HTTPError as e:
            print(f"  module {n}: HTTP error: {e.response.status_code} {e.response.text[:200]}")
        except Exception as e:
            print(f"  module {n}: {type(e).__name__}: {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
