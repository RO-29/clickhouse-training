"""Build context-rich prompts + 'Discuss with AI' URLs for module sections.

Each module's README is split into ## (heading_2) sections; for each one we
generate a self-contained prompt that gives the LLM enough context to answer
deeply (mechanics, when-to-use, comparisons, pitfalls, example). The prompt
is URL-encoded into letmegptthatforyou.com — but the URL prefix is
configurable via env var or function argument so you can point at any chat
front-end (chatgpt.com, claude.ai, etc).
"""
from __future__ import annotations

import re
import urllib.parse

DEFAULT_BASE = "https://letmegptthatforyou.com/?q="

MODULE_TITLES = {
    "module-1-fundamentals":      "ClickHouse Fundamentals",
    "module-2-table-engines":     "ClickHouse Table Engines",
    "module-3-sharding":          "ClickHouse Sharding & Distributed Tables",
    "module-4-replication":       "ClickHouse Replication & High Availability",
    "module-5-cluster-deploy":    "ClickHouse Cluster Deployment",
    "module-6-query-opt":         "ClickHouse Query Optimization",
    "module-7-backup":            "ClickHouse Backup & Recovery",
    "module-8-dr":                "ClickHouse Disaster Recovery",
    "module-9-kafka":             "ClickHouse + Kafka Ingestion",
}

PROMPT_TEMPLATE = """I'm studying ClickHouse and working through the module "{module_title}". I want to deeply understand the section: "{section_title}".

Here is a brief excerpt from the material I'm reading:

\"\"\"
{excerpt}
\"\"\"

Please explain this concept in depth. Cover:

1. **Core mechanics** — how does it actually work under the hood? What data structures, algorithms, or engine internals are involved? Where is the implementation in the ClickHouse source tree (file/folder names) if you know?

2. **When to use vs avoid** — what concrete workloads does this help, and when would it hurt or be wrong? Give specific scale/latency trade-offs.

3. **Comparable features in other systems** — how does this compare with similar features in PostgreSQL, MySQL, BigQuery, Snowflake, Redshift, or DuckDB? Build my intuition by analogy.

4. **Common pitfalls and gotchas** — what trips engineers up in production? Subtle bugs, performance traps, surprising semantics?

5. **Worked example** — show me a small but realistic SQL or config example that demonstrates the concept end-to-end. Include the expected output where useful.

6. **Where to read more** — a short list of authoritative pointers (CH docs, blog posts, talks, source-code files).

Assume I have solid SQL fundamentals but I'm new to ClickHouse internals. Be technical but pragmatic; avoid marketing language.
"""


def build_prompt(module_dir: str, section_title: str, excerpt: str = "") -> str:
    """Render the prompt for a (module, section) pair."""
    module_title = MODULE_TITLES.get(module_dir, module_dir)
    excerpt = excerpt.strip()
    if len(excerpt) > 1200:
        excerpt = excerpt[:1200].rstrip() + " ..."
    if not excerpt:
        excerpt = f"(no excerpt — section heading was \"{section_title}\")"
    return PROMPT_TEMPLATE.format(
        module_title=module_title,
        section_title=section_title,
        excerpt=excerpt,
    )


def build_url(module_dir: str, section_title: str, excerpt: str = "",
              base: str = DEFAULT_BASE, max_url_chars: int = 8000) -> str:
    """URL-encode the prompt onto a chat-front-end URL.

    `max_url_chars` (default 8000) is an upper bound. Notion caps link URLs
    at 2000 chars; pass max_url_chars=1990 for that path. If the encoded
    prompt would overflow, the excerpt is halved repeatedly; if even the
    empty-excerpt prompt overflows, we fall back to a minimal title-only
    prompt that's guaranteed under any reasonable cap.
    """
    cur_excerpt = excerpt or ""
    for _ in range(10):
        prompt = build_prompt(module_dir, section_title, cur_excerpt)
        url = base + urllib.parse.quote(prompt, safe="")
        if len(url) <= max_url_chars:
            return url
        if not cur_excerpt:
            break
        cur_excerpt = cur_excerpt[: len(cur_excerpt) // 2]
    # Last-ditch: minimal prompt
    short = (
        f"I'm studying ClickHouse, module \"{MODULE_TITLES.get(module_dir, module_dir)}\". "
        f"Please explain the concept \"{section_title}\" in depth: how it works, "
        "when to use vs avoid, comparisons with other DBs, common pitfalls, "
        "and a small worked SQL example."
    )
    return base + urllib.parse.quote(short, safe="")


# ---------- README parser: harvest (h2 title, opening excerpt) pairs ----------

def harvest_sections(readme_md: str) -> list[tuple[str, str]]:
    """For each ## heading in the README, return (title, opening excerpt).

    The excerpt is the first non-empty paragraph beneath the heading
    (skipping mermaid blocks, dividers, and HTML comments). Truncated to
    ~600 chars.
    """
    lines = readme_md.splitlines()
    sections: list[tuple[str, str]] = []
    i = 0
    n = len(lines)
    in_fenced = False
    while i < n:
        line = lines[i]
        # Track fenced code blocks
        if re.match(r"^```", line.strip()):
            in_fenced = not in_fenced
            i += 1; continue
        if in_fenced:
            i += 1; continue

        m = re.match(r"^##\s+(.+?)\s*$", line)
        if not m:
            i += 1; continue
        title = m.group(1).strip().lstrip("#").strip()
        # Strip leading emoji + numbering for cleanliness in the prompt
        clean_title = re.sub(r"^[0-9.\s]+", "", title).strip()

        # Walk forward, capturing the first paragraph(s) up to ~600 chars
        i += 1
        excerpt_parts: list[str] = []
        char_budget = 600
        section_in_fenced = False
        while i < n and char_budget > 0:
            l = lines[i]
            stripped = l.strip()
            # End of section?
            if re.match(r"^##\s+", stripped) and not section_in_fenced:
                break
            if re.match(r"^```", stripped):
                section_in_fenced = not section_in_fenced
                i += 1; continue
            if section_in_fenced:
                # Skip code blocks in the excerpt
                i += 1; continue
            if not stripped or stripped.startswith("<!--"):
                i += 1; continue
            # Skip table separator and image lines
            if re.match(r"^[\|+\-:= ]+$", stripped) or stripped.startswith("!["):
                i += 1; continue
            excerpt_parts.append(stripped)
            char_budget -= len(stripped) + 1
            i += 1
        excerpt = " ".join(excerpt_parts)
        if len(excerpt) > 600:
            excerpt = excerpt[:600].rstrip() + "..."
        sections.append((clean_title, excerpt))
    return sections


# ---------- HTML helper for the website ----------

import html as _html


def html_details(prompt: str, summary: str = "💬 Discuss with AI — click to view prompt") -> str:
    """Inline collapsible <details> block.  No external link — the prompt
    is rendered in-place with a copy-to-clipboard button.
    """
    safe = _html.escape(prompt)
    return f'''<details class="ai-discuss">
  <summary>{summary}</summary>
  <div class="ai-discuss-body">
    <div class="ai-discuss-toolbar">
      <button type="button" class="ai-discuss-copy" onclick="(function(b){{const p=b.parentElement.parentElement.querySelector('pre').innerText;navigator.clipboard.writeText(p).then(()=>{{const o=b.textContent;b.textContent='✓ Copied';setTimeout(()=>{{b.textContent=o}},1500);}});}})(this)">📋 Copy prompt</button>
      <span class="ai-discuss-hint">Paste into ChatGPT, Claude, Gemini, or any LLM chat.</span>
    </div>
    <pre>{safe}</pre>
  </div>
</details>'''


HTML_BUTTON_CSS = """
.ai-discuss {
  margin: 12px 0 18px 0;
  border: 1px solid #7dd3fc;
  background: #f0f9ff;
  border-radius: 8px;
  font-size: 0.95em;
}
.ai-discuss summary {
  cursor: pointer;
  padding: 8px 14px;
  font-weight: 600;
  color: #075985;
  user-select: none;
  list-style: none;
}
.ai-discuss summary::before { content: "▶ "; font-size: 0.8em; }
.ai-discuss[open] summary::before { content: "▼ "; }
.ai-discuss summary::-webkit-details-marker { display: none; }
.ai-discuss-body {
  padding: 4px 14px 14px 14px;
  border-top: 1px solid #bae6fd;
  background: #ffffff;
}
.ai-discuss-toolbar {
  display: flex; align-items: center; gap: 14px;
  margin: 10px 0;
}
.ai-discuss-copy {
  background: #0f172a; color: #f1f5f9;
  border: none; border-radius: 6px;
  padding: 6px 14px; font-size: 0.9em;
  cursor: pointer;
}
.ai-discuss-copy:hover { background: #1e293b; }
.ai-discuss-hint { color: #475569; font-size: 0.85em; font-style: italic; }
.ai-discuss pre {
  background: #0f172a; color: #f1f5f9;
  padding: 14px 16px; border-radius: 8px;
  font-family: ui-monospace, Menlo, Consolas, monospace;
  font-size: 0.88em;
  white-space: pre-wrap;
  word-wrap: break-word;
  line-height: 1.55;
  margin: 0;
}
"""
