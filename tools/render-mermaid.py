#!/usr/bin/env python3
"""Extract every ```mermaid``` block from each module README, render to SVG.

Outputs: code-examples/demos/module-N-*/diagrams/<NN>-<slug>.svg

Slug is derived from the first non-blank line of the mermaid block (the
diagram type or first node label).
"""
import re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEMOS = ROOT / "code-examples" / "demos"

MMDC = "mmdc"   # mermaid-cli
THEME = "default"   # 'default' | 'forest' | 'dark' | 'neutral'

def slugify(s: str, n: int = 40) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "-", s).strip("-").lower()
    return s[:n] or "diagram"

def first_meaningful_line(block: str) -> str:
    for line in block.strip().splitlines():
        line = line.strip()
        if not line: continue
        # Skip the diagram-type declarator line (flowchart, sequenceDiagram, etc.)
        if line.split()[0] in ("flowchart","graph","sequenceDiagram","classDiagram",
                               "stateDiagram-v2","stateDiagram","erDiagram","journey","gantt","pie"):
            continue
        return line
    return "diagram"

def render(folder: Path) -> int:
    readme = folder / "README.md"
    if not readme.exists(): return 0
    text = readme.read_text()
    blocks = re.findall(r"```mermaid\n(.+?)\n```", text, flags=re.DOTALL)
    if not blocks: return 0

    out_dir = folder / "diagrams"
    out_dir.mkdir(exist_ok=True)

    rendered = 0
    for i, block in enumerate(blocks, 1):
        seed = first_meaningful_line(block)
        # First line of the block contains the diagram type; use it for the slug
        diagram_type = block.strip().split("\n",1)[0].split()[0]
        slug = f"{i:02d}-{diagram_type.lower()}-{slugify(seed)}"
        # Cap filename length
        slug = slug[:60]

        mmd = out_dir / f"{slug}.mmd"
        svg = out_dir / f"{slug}.svg"
        mmd.write_text(block)
        # mmdc handles theme + transparent bg
        cmd = [MMDC, "-i", str(mmd), "-o", str(svg),
               "-t", THEME, "-b", "transparent", "--quiet"]
        try:
            subprocess.run(cmd, check=True, capture_output=True, timeout=60)
            rendered += 1
            print(f"  ✓ {svg.name}")
        except subprocess.CalledProcessError as e:
            print(f"  ✗ {svg.name}: {e.stderr.decode()[:200]}")
        except subprocess.TimeoutExpired:
            print(f"  ✗ {svg.name}: timeout")
        finally:
            mmd.unlink(missing_ok=True)
    return rendered

def main():
    total = 0
    for folder in sorted(DEMOS.glob("module-*")):
        if not folder.is_dir(): continue
        print(f"== {folder.name} ==")
        total += render(folder)
    print(f"\nTotal: {total} SVG diagrams rendered.")

if __name__ == "__main__":
    sys.exit(main() or 0)
