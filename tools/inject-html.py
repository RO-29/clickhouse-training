#!/usr/bin/env python3
"""Inject the rich training-grade content into each module's HTML page.

For each content/module-N-*.html:
  1. Stage assets under content/demo-assets/<module>/ (GIFs, anim SVGs,
     mermaid SVGs from the demo's diagrams/ folder; external/* already
     populated by tools/fetch-external-images.py).
  2. Strip any existing demo-callout / handsOn block so re-runs are clean.
  3. Insert a richer "Hands-on Reference" section that contains:
        - the demo GIF (large)
        - any animated SVGs from the diagrams/ folder
        - all rendered mermaid SVGs from the diagrams/ folder
        - downloaded CH/Altinity reference images (with source links)
        - the README rendered to HTML

All assets are referenced via demo-assets/<module>/<file> — i.e. paths
relative to the HTML file itself — so they work both via file:// and on
deployed sites regardless of build config.
"""
from __future__ import annotations
import re, shutil, json, sys
from pathlib import Path
import markdown
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ai_prompts import (  # noqa: E402
    harvest_sections, build_url, html_button, HTML_BUTTON_CSS,
)

ROOT = Path(__file__).resolve().parent.parent
DEMOS = ROOT / "code-examples" / "demos"
CONTENT = ROOT / "content"
ASSETS = CONTENT / "demo-assets"
EXTERNAL_SPEC = ROOT / "tools" / "external-images.json"

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
.handsOn-card h2 { margin: 0 0 8px 0; font-size: 1.6em; color: #0f172a; }
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
.handsOn-banner code { background: rgba(0,0,0,0.25); color: #f1f5f9; }
.handsOn-banner pre  { background: rgba(0,0,0,0.30); color: #f1f5f9; }
.handsOn-figure {
  margin: 16px 0; padding: 12px; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 8px; text-align: center;
}
.handsOn-figure img {
  max-width: 100%; height: auto; border-radius: 4px; display: inline-block;
}
.handsOn-figure figcaption {
  margin-top: 8px; color: #475569; font-size: 0.9em; font-style: italic;
}
.handsOn-figure figcaption a {
  color: #1a4480; text-decoration: none; border-bottom: 1px dotted #94a3b8;
}
.handsOn-grid {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(380px, 1fr));
  gap: 16px; margin: 12px 0;
}
.handsOn-card a { color: #1a4480; }
""" + HTML_BUTTON_CSS + """
.handsOn-source-tag {
  display: inline-block; background: #e0f2fe; color: #075985;
  padding: 2px 8px; border-radius: 4px; font-size: 0.8em; font-weight: 600;
  margin-right: 6px;
}
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
      <img src="demo-assets/{folder}/demo.gif" alt="Module demo GIF" loading="lazy">
      <figcaption>Animated GIF, ~{size_kb} KB. Right-click → open in new tab to view full-size.</figcaption>
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
        <img src="demo-assets/{folder}/{filename}" alt="{caption}" loading="lazy">
        <figcaption>{caption}</figcaption>
      </figure>
"""
ANIM_CARD_FOOTER = "    </div>\n  </div>\n</div>\n"

DIAG_CARD_HEADER = """
<div class="handsOn">
  <div class="handsOn-card">
    <h2>🗂️ Architecture diagrams</h2>
    <p>Rendered from the README's Mermaid sources. Click any to open the source SVG full-size.</p>
    <div class="handsOn-grid">
"""
DIAG_FIGURE = """
      <figure class="handsOn-figure">
        <a href="demo-assets/{folder}/{filename}" target="_blank" rel="noopener">
          <img src="demo-assets/{folder}/{filename}" alt="{caption}" loading="lazy">
        </a>
        <figcaption>{caption}</figcaption>
      </figure>
"""
DIAG_CARD_FOOTER = "    </div>\n  </div>\n</div>\n"

EXT_CARD_HEADER = """
<div class="handsOn">
  <div class="handsOn-card">
    <h2>📚 ClickHouse reference visuals</h2>
    <p>Curated from the official ClickHouse documentation and engineering blog (and Altinity's docs/blog) — the same diagrams the broader CH community uses to explain these concepts. Click any image to read the source.</p>
    <div class="handsOn-grid">
"""
EXT_FIGURE = """
      <figure class="handsOn-figure">
        <a href="{src_page}" target="_blank" rel="noopener">
          <img src="demo-assets/{folder}/external/{filename}" alt="{caption}" loading="lazy">
        </a>
        <figcaption>
          <span class="handsOn-source-tag">{src_name}</span>
          {caption}
        </figcaption>
      </figure>
"""
EXT_CARD_FOOTER = "    </div>\n  </div>\n</div>\n"

README_CARD = """
<div class="handsOn">
  <div class="handsOn-card">
    <h2>📚 Full module reference</h2>
    {readme_html}
  </div>
</div>
"""

def caption_from_filename(stem: str) -> str:
    s = re.sub(r"^\d+-", "", stem)
    s = re.sub(r"^(flowchart|sequencediagram|classdiagram|statediagram|erdiagram)-", "", s)
    s = re.sub(r"^anim-", "", s)
    return (s.replace("-", " ").strip() or "Diagram").capitalize()

def stage_assets(demos_folder: Path, module_name: str) -> None:
    """Copy GIFs and SVGs from demos/<m>/diagrams/ into content/demo-assets/<m>/ ."""
    out = ASSETS / module_name
    out.mkdir(parents=True, exist_ok=True)
    src = demos_folder / "diagrams"
    if not src.exists(): return
    for p in src.iterdir():
        if p.is_file() and p.suffix in (".gif", ".svg", ".png", ".jpg", ".webp"):
            dest = out / p.name
            shutil.copy2(p, dest)

def diagram_files(folder: Path) -> tuple[list, list]:
    diag_dir = folder / "diagrams"
    if not diag_dir.exists(): return [], []
    anim, mermaid = [], []
    for p in sorted(diag_dir.glob("*.svg")):
        (anim if p.name.startswith("anim-") else mermaid).append(p)
    return anim, mermaid

def load_readme_as_html(folder: Path, module_dir: str) -> str:
    md_path = folder / "README.md"
    if not md_path.exists(): return "<p><em>README missing.</em></p>"
    text = md_path.read_text()

    # Strip mermaid blocks — already rendered as SVG above this section.
    text = re.sub(r"```mermaid\n.+?\n```",
                  "<!-- mermaid rendered as SVG above -->",
                  text, flags=re.DOTALL)

    html = markdown.markdown(text, extensions=["fenced_code", "tables", "toc", "sane_lists"])

    # Inject 💬 Discuss with AI button next to every <h2>. The Python markdown
    # library uses h2 for ##; that's our section anchor.
    sections = {title: excerpt for title, excerpt in harvest_sections(text)}

    def add_btn(match: re.Match) -> str:
        full_tag = match.group(0)
        title_html = match.group(2)
        # Strip HTML tags from the title to get a clean lookup key
        plain_title = re.sub(r"<[^>]+>", "", title_html).strip()
        # Drop leading numbering / emojis to match harvest's normalisation
        normalised = re.sub(r"^[0-9.\s]+", "", plain_title).strip()
        excerpt = sections.get(normalised) or sections.get(plain_title) or ""
        url = build_url(module_dir, normalised or plain_title, excerpt)
        return f'<h2{match.group(1)}>{title_html}{html_button(url)}</h2>'

    html = re.sub(r'<h2([^>]*)>(.+?)</h2>', add_btn, html, flags=re.DOTALL)
    return html

def slug_for(url: str, idx: int) -> str:
    """Match the slug rules used by fetch-external-images.py."""
    name = url.rsplit("/", 1)[-1]
    if "." not in name: return f"{idx:02d}-img"
    stem, ext = name.rsplit(".", 1)
    if "-" in stem and len(stem.split("-")[-1]) == 32:
        stem = "-".join(stem.split("-")[:-1])
    return f"{idx:02d}-{stem}.{ext.lower()}"

def build_section(folder_name: str, demos_folder: Path, externals: list) -> str:
    parts = [CSS, BANNER.format(folder=folder_name)]

    gif = ASSETS / folder_name / "demo.gif"
    if gif.exists():
        parts.append(GIF_CARD.format(folder=folder_name, size_kb=gif.stat().st_size // 1024))

    anim, mermaid = diagram_files(demos_folder)
    if anim:
        parts.append(ANIM_CARD_HEADER)
        for f in anim:
            parts.append(ANIM_FIGURE.format(folder=folder_name, filename=f.name,
                                             caption=caption_from_filename(f.stem)))
        parts.append(ANIM_CARD_FOOTER)

    if mermaid:
        parts.append(DIAG_CARD_HEADER)
        for f in mermaid:
            parts.append(DIAG_FIGURE.format(folder=folder_name, filename=f.name,
                                             caption=caption_from_filename(f.stem)))
        parts.append(DIAG_CARD_FOOTER)

    if externals:
        parts.append(EXT_CARD_HEADER)
        for i, (url, caption, src_url, src_name) in enumerate(externals, 1):
            parts.append(EXT_FIGURE.format(
                folder=folder_name, filename=slug_for(url, i),
                caption=caption, src_page=src_url, src_name=src_name,
            ))
        parts.append(EXT_CARD_FOOTER)

    parts.append(README_CARD.format(readme_html=load_readme_as_html(demos_folder, folder_name)))
    return "\n".join(parts)

def main():
    ASSETS.mkdir(exist_ok=True)
    externals = json.loads(EXTERNAL_SPEC.read_text()) if EXTERNAL_SPEC.exists() else {}

    for html_name, demo_dir in MAP:
        html_path = CONTENT / html_name
        demos_folder = DEMOS / demo_dir
        if not html_path.exists() or not demos_folder.exists():
            print(f"  ✗ skip {html_name}"); continue

        stage_assets(demos_folder, demo_dir)

        section = build_section(demo_dir, demos_folder, externals.get(demo_dir, []))
        text = html_path.read_text()

        # Wipe prior demo-callout block (very old format)
        text = re.sub(r'<!-- demo-callout:.*?</div>\s*</div>\s*</div>\s*', "",
                       text, count=1, flags=re.DOTALL)
        # Wipe prior <style>.handsOn ...</style> block(s)
        text = re.sub(r"<style>\s*\.handsOn .+?</style>", "", text, flags=re.DOTALL)
        # Wipe prior handsOn cards
        text = re.sub(r'<div class="handsOn">.*?</div>\s*</div>\s*',
                      "", text, flags=re.DOTALL)

        # Inject BEFORE the dark module-footer block so the new content
        # sits at the end of the curriculum body, not after the footer.
        # Anchor present on every module page:
        FOOTER = '<div style="background: #333; color: white; padding: 40px 20px; text-align: center; margin-top: 40px;">'
        if FOOTER in text:
            text = text.replace(FOOTER, section + "\n" + FOOTER, 1)
        elif "</body>" in text:
            text = text.replace("</body>", section + "\n</body>", 1)
        else:
            text += "\n" + section
        html_path.write_text(text)
        print(f"  ✓ {html_name}")

if __name__ == "__main__":
    main()
