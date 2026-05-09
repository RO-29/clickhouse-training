#!/usr/bin/env python3
"""Inject the rich training-grade content into each module's HTML page.

For each content/module-N-*.html:
  1. Strip the existing minimal demo-callout block.
  2. Insert a richer "Hands-on Reference" section that contains:
        - the demo GIF (large)
        - any animated SVGs from the diagrams/ folder
        - all rendered mermaid SVGs from the diagrams/ folder
        - the README rendered to HTML
        - a footer link block to the demo folder + Notion (no GitHub)
"""
from __future__ import annotations
import re, shutil
from pathlib import Path
import markdown

ROOT = Path(__file__).resolve().parent.parent
DEMOS = ROOT / "code-examples" / "demos"
CONTENT = ROOT / "content"
# We don't copy assets — both Netlify and Render publish from repo root,
# so HTML at content/*.html can reference ../code-examples/demos/<m>/diagrams/<f>
# directly. The path prefix below is what gets baked into the HTML.
ASSET_PREFIX = "../code-examples/demos"

# (html-name, demo-folder)
MAP = [
    ("module-1-fundamentals.html",      "module-1-fundamentals"),
    ("module-2-table-engines.html",     "module-2-table-engines"),
    ("module-3-sharding.html",          "module-3-sharding"),
    ("module-4-replication.html",       "module-4-replication"),
    ("module-5-cluster-deployment.html","module-5-cluster-deploy"),
    ("module-6-query-optimization.html","module-6-query-opt"),
    ("module-7-backup-recovery.html",   "module-7-backup"),
    ("module-8-disaster-recovery.html", "module-8-dr"),
    ("module-9-kafka-ingestion.html",   "module-9-kafka"),
]

CSS = """
<style>
.handsOn {
  margin: 24px auto; max-width: 1200px; padding: 0 20px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
}
.handsOn-card {
  background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05); padding: 28px 32px; margin-bottom: 24px;
}
.handsOn-card h2 {
  margin: 0 0 8px 0; font-size: 1.6em; color: #0f172a;
}
.handsOn-card h3 {
  margin: 24px 0 8px 0; font-size: 1.2em; color: #1a4480;
  border-bottom: 1px solid #e2e8f0; padding-bottom: 4px;
}
.handsOn-card h4 { margin: 16px 0 6px 0; color: #0f172a; }
.handsOn-card p, .handsOn-card li { color: #1e293b; line-height: 1.6; }
.handsOn-card code {
  background: #f1f5f9; padding: 2px 6px; border-radius: 4px;
  font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 0.92em;
}
.handsOn-card pre {
  background: #0f172a; color: #f1f5f9; padding: 16px 18px; border-radius: 8px;
  overflow-x: auto; font-family: ui-monospace, Menlo, Consolas, monospace;
  font-size: 0.9em; line-height: 1.5;
}
.handsOn-card pre code { background: transparent; padding: 0; color: inherit; }
.handsOn-card table {
  border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 0.93em;
}
.handsOn-card th, .handsOn-card td {
  border: 1px solid #e2e8f0; padding: 8px 12px; text-align: left;
}
.handsOn-card th { background: #f8fafc; color: #0f172a; }
.handsOn-banner {
  background: linear-gradient(135deg, #2b6cb0 0%, #1a4480 100%); color: white;
  padding: 28px 32px; border-radius: 12px; margin-bottom: 20px;
}
.handsOn-banner h2 { color: white; margin: 0 0 8px 0; }
.handsOn-banner code {
  background: rgba(0,0,0,0.25); color: #f1f5f9;
}
.handsOn-banner pre {
  background: rgba(0,0,0,0.30); color: #f1f5f9;
}
.handsOn-figure {
  margin: 16px 0; padding: 12px; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 8px; text-align: center;
}
.handsOn-figure img, .handsOn-figure object {
  max-width: 100%; height: auto; border-radius: 4px;
}
.handsOn-figure figcaption {
  margin-top: 8px; color: #475569; font-size: 0.9em; font-style: italic;
}
.handsOn-grid {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(380px, 1fr));
  gap: 16px; margin: 12px 0;
}
.handsOn-card a { color: #1a4480; }
</style>
"""

BANNER = """
<div class="handsOn">
  <div class="handsOn-banner">
    <h2>🐳 Hands-on Docker Demo for this Module</h2>
    <p style="opacity:0.92; line-height:1.55;">A self-contained ClickHouse stack you can run locally. Every step is reproducible; the README below walks through each concept with diagrams and measured outcomes.</p>
    <pre><code>cd code-examples/demos/{folder}
./up.sh        # bring stack up, wait for health
./run.sh       # run the demo (idempotent — re-runnable)
./down.sh      # tear down + drop volumes</code></pre>
  </div>
</div>
"""

GIF_CARD = """
<div class="handsOn">
  <div class="handsOn-card">
    <h2>📺 Live demo capture</h2>
    <p>Recorded with <a href="https://github.com/charmbracelet/vhs" target="_blank" rel="noopener">vhs</a>: the actual terminal output from <code>./run.sh</code> running on this very stack.</p>
    <figure class="handsOn-figure">
      <img src="{prefix}/{folder}/diagrams/demo.gif" alt="Module demo GIF" loading="lazy">
      <figcaption>Click to view full-size. Animated GIF, ~{size_kb} KB.</figcaption>
    </figure>
  </div>
</div>
"""

ANIM_CARD_HEADER = """
<div class="handsOn">
  <div class="handsOn-card">
    <h2>✨ Animated concept diagrams</h2>
    <p>Inline SVG animations — no plugins, native browser playback. Each visualises a key flow this module covers.</p>
    <div class="handsOn-grid">
"""

ANIM_FIGURE = """
      <figure class="handsOn-figure">
        <object type="image/svg+xml" data="{prefix}/{folder}/diagrams/{filename}" aria-label="{caption}"></object>
        <figcaption>{caption}</figcaption>
      </figure>
"""

ANIM_CARD_FOOTER = """
    </div>
  </div>
</div>
"""

DIAG_CARD_HEADER = """
<div class="handsOn">
  <div class="handsOn-card">
    <h2>🗂️ Architecture diagrams</h2>
    <p>Rendered from the README's Mermaid sources. Static, but click any to view the source SVG full-size.</p>
    <div class="handsOn-grid">
"""

DIAG_FIGURE = """
      <figure class="handsOn-figure">
        <a href="{prefix}/{folder}/diagrams/{filename}" target="_blank" rel="noopener">
          <img src="{prefix}/{folder}/diagrams/{filename}" alt="{caption}" loading="lazy">
        </a>
        <figcaption>{caption}</figcaption>
      </figure>
"""

DIAG_CARD_FOOTER = """
    </div>
  </div>
</div>
"""

README_CARD = """
<div class="handsOn">
  <div class="handsOn-card">
    <h2>📚 Full module reference</h2>
    {readme_html}
  </div>
</div>
"""

def caption_from_filename(stem: str) -> str:
    """Turn '01-flowchart-source-20m-synthetic-events' into something readable."""
    s = re.sub(r"^\d+-", "", stem)
    s = re.sub(r"^(flowchart|sequencediagram|classdiagram|statediagram|erdiagram)-", "", s)
    s = re.sub(r"^anim-", "", s)
    s = s.replace("-", " ").strip()
    return s.capitalize() if s else "Diagram"

def diagram_files(folder: Path) -> tuple[list, list]:
    diag_dir = folder / "diagrams"
    if not diag_dir.exists():
        return [], []
    anim, mermaid = [], []
    for p in sorted(diag_dir.glob("*.svg")):
        if p.name.startswith("anim-"):
            anim.append(p)
        else:
            mermaid.append(p)
    return anim, mermaid

def load_readme_as_html(folder: Path) -> str:
    md_path = folder / "README.md"
    if not md_path.exists():
        return "<p><em>README missing.</em></p>"
    text = md_path.read_text()
    # Strip mermaid blocks — the rendered SVGs are already shown above.
    text = re.sub(r"```mermaid\n.+?\n```", "<!-- mermaid rendered as SVG above -->", text, flags=re.DOTALL)
    return markdown.markdown(text, extensions=["fenced_code", "tables", "toc", "sane_lists"])

def build_section(folder_name: str, demos_folder: Path) -> str:
    parts = [CSS]
    # Banner with run instructions
    parts.append(BANNER.format(folder=folder_name))

    # Live GIF
    gif = demos_folder / "diagrams" / "demo.gif"
    if gif.exists():
        parts.append(GIF_CARD.format(prefix=ASSET_PREFIX, folder=folder_name, size_kb=gif.stat().st_size // 1024))

    # Animated SVGs
    anim, mermaid = diagram_files(demos_folder)
    if anim:
        parts.append(ANIM_CARD_HEADER)
        for f in anim:
            parts.append(ANIM_FIGURE.format(
                prefix=ASSET_PREFIX, folder=folder_name, filename=f.name,
                caption=caption_from_filename(f.stem),
            ))
        parts.append(ANIM_CARD_FOOTER)

    if mermaid:
        parts.append(DIAG_CARD_HEADER)
        for f in mermaid:
            parts.append(DIAG_FIGURE.format(
                prefix=ASSET_PREFIX, folder=folder_name, filename=f.name,
                caption=caption_from_filename(f.stem),
            ))
        parts.append(DIAG_CARD_FOOTER)

    # README rendered to HTML
    parts.append(README_CARD.format(readme_html=load_readme_as_html(demos_folder)))

    return "\n".join(parts)


def main():
    for html_name, demo_dir in MAP:
        html_path = CONTENT / html_name
        demos_folder = DEMOS / demo_dir
        if not html_path.exists():
            print(f"  ✗ {html_name} (missing)"); continue
        if not demos_folder.exists():
            print(f"  ✗ {html_name} (no demo folder)"); continue

        # Stage assets next to the HTML
        # Build the new section and inject before </body>
        section = build_section(demo_dir, demos_folder)
        text = html_path.read_text()

        # Strip prior demo-callout block (the simple one) if present
        text = re.sub(
            r'<!-- demo-callout:.*?</div>\n</div>\n</div>\n',
            "",
            text,
            count=1,
            flags=re.DOTALL,
        )
        # Strip prior handsOn block on re-runs
        text = re.sub(
            r"<style>\n\.handsOn .+?</style>",
            "",
            text,
            flags=re.DOTALL,
        )
        text = re.sub(
            r'<div class="handsOn".*?</div>\s*</div>\s*</div>\s*',
            "",
            text,
            flags=re.DOTALL,
        )
        # Inject at the end, before </body>
        if "</body>" in text:
            text = text.replace("</body>", section + "\n</body>", 1)
        else:
            text += "\n" + section
        html_path.write_text(text)
        print(f"  ✓ {html_name}")

if __name__ == "__main__":
    main()
