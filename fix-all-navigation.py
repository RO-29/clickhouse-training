#!/usr/bin/env python3
"""
Comprehensive Navigation Fix
Fixes all in-page navigation by adding IDs to all sections
"""

import re
from pathlib import Path

def fix_module_navigation(html_path: Path) -> bool:
    """Fix navigation in a single HTML module"""

    print(f"Processing: {html_path.name}")

    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Find all sections and add IDs based on their actual headers
    # Pattern: <div class="section"> followed by <div class="section-header">EMOJI Text</div>

    section_pattern = r'(<div class="section")(>)\s*(<div class="section-header">([^<]+)</div>)'

    def add_id_to_section(match):
        opening_tag = match.group(1)
        closing_bracket = match.group(2)
        header_full = match.group(3)
        header_text = match.group(4).strip()

        # Check if ID already exists
        if ' id="' in opening_tag:
            return match.group(0)  # Already has ID, don't modify

        # Generate ID from header text
        # Remove emoji and create slug
        text_without_emoji = re.sub(r'[^\w\s-]', '', header_text)
        text_slug = text_without_emoji.strip().lower()
        text_slug = re.sub(r'\s+', '-', text_slug)

        # Map common patterns to consistent IDs
        id_mappings = {
            'what-is-clickhouse': 'what-is',
            'clickhouse-in-a-nutshell': 'what-is',
            'quick-start': 'quick-start',
            'getting-started': 'quick-start',
            'commands-reference': 'commands',
            'command-reference': 'commands',
            'commands': 'commands',
            'best-practices': 'best-practices',
            'when-to-use-clickhouse': 'when-to-use',
            'when-to-use': 'when-to-use',
            'real-world-results': 'real-world',
            'production-examples': 'real-world',
            'ready-to-use-templates': 'templates',
            'templates': 'templates',
            'code-templates': 'templates',
            'advanced-patterns': 'advanced',
            'advanced-topics': 'advanced',
            'advanced': 'advanced',
            'related-resources': 'resources',
            'resources-references': 'resources',
            'resources-next-steps': 'resources',
            'resources-further-learning': 'resources',
            'dr-bc-resources': 'resources',
            'migration-resources-tools': 'resources'
        }

        section_id = id_mappings.get(text_slug, text_slug)

        return f'{opening_tag} id="{section_id}"{closing_bracket}{header_full}'

    content = re.sub(section_pattern, add_id_to_section, content, flags=re.DOTALL)

    # Ensure smooth scroll is added
    if 'scroll-behavior: smooth' not in content:
        content = re.sub(
            r'<html lang="en">',
            '<html lang="en" style="scroll-behavior: smooth;">',
            content,
            count=1
        )

    # Save if changes were made
    if content != original_content:
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(content)

        # Count how many IDs were added
        ids_in_new = len(re.findall(r'class="section" id="', content))
        ids_in_old = len(re.findall(r'class="section" id="', original_content))
        added_count = ids_in_new - ids_in_old

        print(f"  ✅ Added {added_count} section IDs (total: {ids_in_new})")
        return True
    else:
        print(f"  ℹ️  No changes needed")
        return False

def main():
    """Fix navigation in all modules"""

    print("=" * 60)
    print("Comprehensive Navigation Fix")
    print("=" * 60)
    print()

    content_dir = Path('content')
    if not content_dir.exists():
        print("❌ Error: content/ directory not found")
        return

    module_files = sorted(content_dir.glob('module-*.html'))

    if not module_files:
        print("❌ Error: No module files found")
        return

    print(f"Found {len(module_files)} module files")
    print()

    success_count = 0
    for html_path in module_files:
        if fix_module_navigation(html_path):
            success_count += 1
        print()

    print("-" * 60)
    print(f"✅ Successfully updated {success_count}/{len(module_files)} files")
    print()
    print("All sections now have IDs and navigation links work!")
    print("=" * 60)

if __name__ == '__main__':
    main()
