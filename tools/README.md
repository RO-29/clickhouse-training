# tools/

One-shot utilities. Currently:

## `sync-demos-to-notion.py`

Pushes each module's hands-on Docker demo (under
`code-examples/demos/module-N-*/`) into Notion as a **child page** under that
module's existing Notion page. Idempotent: re-running archives the prior
child and creates a fresh one with the latest content.

### What ends up in Notion

For every module 1–9, a sub-page titled **🐳 Hands-on Docker Demo** is
created under the existing module page. It contains:

1. A 1-line summary linking to the GitHub README (which has the full
   step-by-step execution flow).
2. A **Run locally** code block — the three commands you need
   (`./up.sh && ./run.sh && ./down.sh`).
3. A **Links** bullet list — README, demo folder, every file individually.
4. A **Source files** section with `setup.sql`, `data.sql`/`data.py`,
   `queries.sql`, `extras.sql` (plus `produce.py` and any `configs/*.xml`)
   reproduced as syntax-highlighted code blocks. Long files are
   automatically split to fit Notion's 2000-char per-block limit.

The original module page is untouched; the demo lives as a child page so
your existing curriculum content stays clean.

### Setup

1. **Create a Notion integration** at
   <https://www.notion.so/my-integrations> and copy the secret token.
2. **Share each module page** with the integration (Notion → page → ⋯ →
   Connections → add your integration).
3. **Map module numbers to page IDs**:
   ```bash
   cp tools/notion-page-ids.example.json tools/notion-page-ids.json
   # Edit notion-page-ids.json — replace each placeholder with the 32-char
   # hex at the end of the page's Notion URL.
   ```
4. **Set the API token in your environment**:
   ```bash
   export NOTION_API_KEY=secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

### Run

```bash
# Sync every module that has a mapping in notion-page-ids.json
python3 tools/sync-demos-to-notion.py

# Sync only specific modules
python3 tools/sync-demos-to-notion.py 3 6
```

Output looks like:

```
Syncing modules: [1, 2, 3, 4, 5, 6, 7, 8, 9]
  module 1 (module-1-fundamentals):
    archived 1 prior demo child page(s)
    ✓ https://www.notion.so/Hands-on-Docker-Demo-...
  module 2 (module-2-table-engines):
    ✓ https://www.notion.so/Hands-on-Docker-Demo-...
  ...
```

### Dependencies

Just `requests`:

```bash
pip install requests
```

(or use the `requirements.txt` at repo root).

### How it handles re-runs

The script archives any prior child page titled exactly **🐳 Hands-on
Docker Demo** before creating the new one. So you can re-run after editing
demo SQL and Notion stays in sync without manual cleanup.

### Limitations

- Doesn't render the README's markdown into Notion blocks. The README on
  GitHub is the source of truth — Notion gets the runnable code instead.
- Doesn't rate-limit aggressively. Notion's published limit is ~3 req/s;
  this script does ~5–10 req/module, well within bounds for 9 modules.
- Module 10 (migration) has no demo and is skipped.
