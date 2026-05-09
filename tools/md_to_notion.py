"""Markdown → Notion blocks converter (with optional 'Discuss with AI'
links injected after each h2 heading).

Focused on the patterns our module READMEs use:

  # / ## / ### headings        →  heading_1/2/3
  paragraphs                   →  paragraph
  - bullet                     →  bulleted_list_item
  1. numbered                  →  numbered_list_item
  > blockquote                 →  quote
  ---                          →  divider
  ``` fenced code ```          →  code  (chunked to fit 2000-char limit)
  | markdown | tables |        →  table + table_row
  inline `code`, **bold**, *em*, [text](url)  → rich_text annotations
  ![alt](url)                  →  image (external)

Notion API limits we respect:
  - 2000 chars per rich_text content piece (we chunk)
  - 100 blocks per request (caller paginates)
"""
from __future__ import annotations
import re
from typing import Any

RICH_TEXT_MAX = 2000

# ---------- rich_text builders ----------

def _rt_text(content: str, *, bold=False, italic=False, code=False,
             link: str | None = None) -> dict:
    annotations = {"bold": bold, "italic": italic, "strikethrough": False,
                   "underline": False, "code": code, "color": "default"}
    text = {"content": content}
    if link:
        text["link"] = {"url": link}
    return {"type": "text", "text": text, "annotations": annotations}


# Inline regex: order matters — code first (won't apply other styles inside).
_INLINE = re.compile(
    r"`([^`]+)`"                                  # group 1: inline code
    r"|\*\*([^*]+)\*\*"                            # group 2: bold
    r"|__([^_]+)__"                                # group 3: bold (alt)
    r"|\*([^*]+)\*"                                # group 4: italic
    r"|(?<!\w)_([^_]+)_(?!\w)"                     # group 5: italic (alt, word-bound)
    r"|\[([^\]]+)\]\(([^\)]+)\)"                   # group 6,7: link [text](url)
)


def parse_inline(text: str) -> list[dict]:
    """Convert one line of inline markdown to a list of rich_text objects."""
    if not text:
        return []
    out: list[dict] = []
    pos = 0
    for m in _INLINE.finditer(text):
        start = m.start()
        if start > pos:
            out.extend(_chunk_plain(text[pos:start]))
        if m.group(1) is not None:           # `code`
            out.append(_rt_text(m.group(1), code=True))
        elif m.group(2) is not None:          # **bold**
            out.append(_rt_text(m.group(2), bold=True))
        elif m.group(3) is not None:          # __bold__
            out.append(_rt_text(m.group(3), bold=True))
        elif m.group(4) is not None:          # *italic*
            out.append(_rt_text(m.group(4), italic=True))
        elif m.group(5) is not None:          # _italic_
            out.append(_rt_text(m.group(5), italic=True))
        elif m.group(6) is not None:          # [text](url)
            out.append(_rt_text(m.group(6), link=m.group(7)))
        pos = m.end()
    if pos < len(text):
        out.extend(_chunk_plain(text[pos:]))
    return out


def _chunk_plain(text: str) -> list[dict]:
    """Plain text → one or more rich_text blocks, each ≤ RICH_TEXT_MAX."""
    if not text: return []
    out = []
    while text:
        out.append(_rt_text(text[:RICH_TEXT_MAX]))
        text = text[RICH_TEXT_MAX:]
    return out


# ---------- block builders ----------

def heading(level: int, text: str) -> dict:
    key = {1: "heading_1", 2: "heading_2", 3: "heading_3"}[max(1, min(3, level))]
    return {"object": "block", "type": key, key: {"rich_text": parse_inline(text)}}


def paragraph(text: str) -> dict:
    return {"object": "block", "type": "paragraph",
            "paragraph": {"rich_text": parse_inline(text)}}


def bullet(text: str) -> dict:
    return {"object": "block", "type": "bulleted_list_item",
            "bulleted_list_item": {"rich_text": parse_inline(text)}}


def numbered(text: str) -> dict:
    return {"object": "block", "type": "numbered_list_item",
            "numbered_list_item": {"rich_text": parse_inline(text)}}


def quote(text: str) -> dict:
    return {"object": "block", "type": "quote",
            "quote": {"rich_text": parse_inline(text)}}


def divider() -> dict:
    return {"object": "block", "type": "divider", "divider": {}}


def code_block(content: str, language: str = "plain text") -> list[dict]:
    """Notion's 2000-char limit applies. Split on newlines if needed."""
    if not content:
        return [{
            "object": "block", "type": "code",
            "code": {"language": language, "rich_text": [_rt_text("")]},
        }]
    blocks = []
    chunks = []
    buf = ""
    for line in content.splitlines(keepends=True):
        if len(buf) + len(line) > RICH_TEXT_MAX:
            if buf: chunks.append(buf); buf = ""
            while len(line) > RICH_TEXT_MAX:
                chunks.append(line[:RICH_TEXT_MAX]); line = line[RICH_TEXT_MAX:]
        buf += line
    if buf: chunks.append(buf)
    for chunk in chunks:
        blocks.append({
            "object": "block", "type": "code",
            "code": {"language": language, "rich_text": [_rt_text(chunk)]},
        })
    return blocks


def image_external(url: str, caption: str = "") -> dict:
    block = {
        "object": "block", "type": "image",
        "image": {"type": "external", "external": {"url": url}},
    }
    if caption:
        block["image"]["caption"] = parse_inline(caption)
    return block


def table_block(rows: list[list[str]]) -> dict:
    """Build a Notion table from a list of rows, where rows[0] is the header."""
    if not rows:
        return paragraph("(empty table)")
    width = max(len(r) for r in rows)
    children = []
    for i, row in enumerate(rows):
        cells = []
        for j in range(width):
            cell = row[j] if j < len(row) else ""
            cells.append(parse_inline(cell))
        children.append({
            "object": "block", "type": "table_row",
            "table_row": {"cells": cells},
        })
    return {
        "object": "block", "type": "table",
        "table": {
            "table_width": width,
            "has_column_header": True,
            "has_row_header": False,
            "children": children,
        },
    }


# ---------- markdown → blocks parser ----------

_LANG_MAP = {
    "py": "python", "python": "python",
    "sh": "bash", "bash": "bash", "shell": "shell",
    "sql": "sql",
    "js": "javascript", "javascript": "javascript", "ts": "typescript",
    "yml": "yaml", "yaml": "yaml",
    "xml": "xml", "html": "html", "css": "css",
    "json": "json", "diff": "diff", "go": "go", "rust": "rust",
    "mermaid": "plain text",   # Notion doesn't render mermaid; ship as plain
}


def _normalize_lang(lang: str) -> str:
    return _LANG_MAP.get(lang.lower().strip(), "plain text")


def md_to_blocks(md: str, ai_link_for_h2 = None) -> list[dict]:
    """Convert a markdown document to a list of Notion blocks.

    If ``ai_link_for_h2`` is provided, it's called as ``ai_link_for_h2(title,
    excerpt)`` for every heading_2 we emit and should return a URL — a
    callout block with a link is inserted right after the heading.
    The excerpt is the joined-up paragraph text following the heading
    (capped at 600 chars).
    """
    lines = md.splitlines()
    out: list[dict] = []
    i = 0
    n = len(lines)

    def is_table_separator(s: str) -> bool:
        # |---|---|---| with optional spaces and colons
        return bool(re.match(r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$", s))

    def split_table_row(s: str) -> list[str]:
        s = s.strip()
        if s.startswith("|"): s = s[1:]
        if s.endswith("|"): s = s[:-1]
        return [c.strip() for c in s.split("|")]

    while i < n:
        line = lines[i]
        stripped = line.strip()

        # Blank line
        if not stripped:
            i += 1; continue

        # Fenced code block
        m = re.match(r"^```\s*([\w-]*)\s*$", stripped)
        if m:
            lang = _normalize_lang(m.group(1) or "")
            code_lines = []
            i += 1
            while i < n and not lines[i].rstrip().startswith("```"):
                code_lines.append(lines[i]); i += 1
            if i < n: i += 1   # skip closing ```
            out.extend(code_block("\n".join(code_lines), lang))
            continue

        # Horizontal rule
        if re.match(r"^(-{3,}|\*{3,}|_{3,})$", stripped):
            out.append(divider()); i += 1; continue

        # Heading
        m = re.match(r"^(#{1,6})\s+(.+)$", stripped)
        if m:
            level = len(m.group(1))
            title = m.group(2).rstrip("# ").strip()
            out.append(heading(level, title))
            i += 1
            # If this is an h2 and the caller wants AI links, peek ahead to
            # collect a 600-char excerpt (skipping fenced code, blanks, comments).
            if level == 2 and ai_link_for_h2:
                excerpt_buf, budget, j = [], 600, i
                in_code = False
                while j < n and budget > 0:
                    ll = lines[j].strip()
                    if re.match(r"^##\s+", ll) and not in_code: break
                    if re.match(r"^```", ll):
                        in_code = not in_code; j += 1; continue
                    if in_code: j += 1; continue
                    if not ll or ll.startswith("<!--") or re.match(r"^[\|+\-:= ]+$", ll) or ll.startswith("!["):
                        j += 1; continue
                    excerpt_buf.append(ll); budget -= len(ll) + 1; j += 1
                excerpt = " ".join(excerpt_buf)[:600]
                # Strip emoji/numbering for cleaner prompt title
                normalised = re.sub(r"^[0-9.\s]+", "", title).strip()
                url = ai_link_for_h2(normalised or title, excerpt)
                if url:
                    out.append({
                        "object": "block",
                        "type": "callout",
                        "callout": {
                            "icon": {"type": "emoji", "emoji": "💬"},
                            "color": "blue_background",
                            "rich_text": [
                                _rt_text("Discuss with AI: ", italic=True),
                                _rt_text("open in chat", link=url),
                                _rt_text("  (a context-rich prompt is pre-filled)", italic=True),
                            ],
                        },
                    })
            continue

        # Block quote
        if stripped.startswith(">"):
            quote_lines = []
            while i < n and lines[i].strip().startswith(">"):
                quote_lines.append(re.sub(r"^>\s?", "", lines[i].strip()))
                i += 1
            out.append(quote(" ".join(quote_lines).strip()))
            continue

        # Bulleted list (handles `-`, `*`, `+`)
        if re.match(r"^[\-\*\+]\s+", stripped):
            while i < n and re.match(r"^\s*[\-\*\+]\s+", lines[i]) and lines[i].strip():
                bullet_text = re.sub(r"^\s*[\-\*\+]\s+", "", lines[i])
                out.append(bullet(bullet_text))
                i += 1
            continue

        # Numbered list
        if re.match(r"^\d+\.\s+", stripped):
            while i < n and re.match(r"^\s*\d+\.\s+", lines[i]) and lines[i].strip():
                num_text = re.sub(r"^\s*\d+\.\s+", "", lines[i])
                out.append(numbered(num_text))
                i += 1
            continue

        # Table: a line of cells followed by a separator
        if "|" in stripped and i + 1 < n and is_table_separator(lines[i + 1]):
            header = split_table_row(lines[i])
            rows = [header]
            i += 2  # skip separator
            while i < n and "|" in lines[i].strip() and lines[i].strip():
                rows.append(split_table_row(lines[i])); i += 1
            out.append(table_block(rows))
            continue

        # Image-only line: ![alt](url)  → image block
        m = re.match(r"^!\[([^\]]*)\]\(([^\)]+)\)$", stripped)
        if m:
            out.append(image_external(m.group(2), caption=m.group(1) or ""))
            i += 1; continue

        # Paragraph: collect consecutive non-empty non-list lines
        para = [stripped]
        i += 1
        while i < n and lines[i].strip() and not (
            re.match(r"^(#{1,6}\s|>|[\-\*\+]\s|\d+\.\s|```|---|___|\*\*\*)", lines[i].strip())
            or "|" in lines[i].strip() and i + 1 < n and is_table_separator(lines[i + 1])
        ):
            para.append(lines[i].strip()); i += 1
        joined = " ".join(para)
        # Skip HTML comments and empty paragraphs.
        if joined.startswith("<!--") and joined.endswith("-->"):
            continue
        out.append(paragraph(joined))

    return out
