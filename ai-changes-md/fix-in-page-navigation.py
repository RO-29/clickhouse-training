#!/usr/bin/env python3
"""
Fix In-Page Navigation for All Modules
Converts nav-btn divs to anchor links and adds section IDs
"""

import re
from pathlib import Path

# Section mappings - nav button text to section ID and section header pattern
SECTION_MAPPINGS = [
    {
        'nav_text': '📖 What is ClickHouse?',
        'section_id': 'what-is',
        'header_pattern': r'📖 What is ClickHouse\?'
    },
    {
        'nav_text': '🚀 Quick Start',
        'section_id': 'quick-start',
        'header_pattern': r'🚀 Quick Start'
    },
    {
        'nav_text': '💻 Commands',
        'section_id': 'commands',
        'header_pattern': r'💻 Commands'
    },
    {
        'nav_text': '✨ Best Practices',
        'section_id': 'best-practices',
        'header_pattern': r'✨ Best Practices'
    },
    {
        'nav_text': '🎯 When to Use',
        'section_id': 'when-to-use',
        'header_pattern': r'🎯 When to Use'
    },
    {
        'nav_text': '🏆 Real-World Results',
        'section_id': 'real-world',
        'header_pattern': r'🏆 Real-World Results'
    },
    {
        'nav_text': '📋 Templates',
        'section_id': 'templates',
        'header_pattern': r'📋 Templates'
    },
    {
        'nav_text': '🔥 Advanced',
        'section_id': 'advanced',
        'header_pattern': r'🔥 Advanced'
    },
    {
        'nav_text': '📚 Resources',
        'section_id': 'resources',
        'header_pattern': r'📚.*Resources'
    }
]

def fix_module_navigation(html_path: Path) -> bool:
    """Fix navigation in a single HTML module"""

    print(f"Processing: {html_path.name}")

    # Read the file
    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Step 1: Add IDs to sections
    for mapping in SECTION_MAPPINGS:
        section_id = mapping['section_id']
        header_pattern = mapping['header_pattern']

        # Pattern to find section div with matching header
        pattern = rf'(<div class="section">)\s*(<div class="section-header">{header_pattern}</div>)'
        replacement = rf'<div class="section" id="{section_id}">\2'

        content = re.sub(pattern, replacement, content, count=1, flags=re.IGNORECASE)

    # Step 2: Convert nav-btn divs to anchor links
    for mapping in SECTION_MAPPINGS:
        nav_text = re.escape(mapping['nav_text'])
        section_id = mapping['section_id']

        # Pattern to match nav-btn div
        pattern = rf'<div class="nav-btn">{nav_text}</div>'
        replacement = f'<a href="#{section_id}" class="nav-btn">{mapping["nav_text"]}</a>'

        content = re.sub(pattern, replacement, content, count=1)

    # Step 3: Add smooth scroll CSS if not present
    if 'scroll-behavior: smooth' not in content:
        # Add to html tag style
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
        print(f"  ✅ Updated {html_path.name}")
        return True
    else:
        print(f"  ℹ️  No changes needed for {html_path.name}")
        return False

def main():
    """Fix navigation in all modules"""

    print("=" * 60)
    print("Fix In-Page Navigation - All Modules")
    print("=" * 60)
    print()

    content_dir = Path('content')
    if not content_dir.exists():
        print("❌ Error: content/ directory not found")
        return

    # Find all module HTML files
    module_files = sorted(content_dir.glob('module-*.html'))

    if not module_files:
        print("❌ Error: No module files found")
        return

    print(f"Found {len(module_files)} module files")
    print()

    # Process each file
    success_count = 0
    for html_path in module_files:
        if fix_module_navigation(html_path):
            success_count += 1
        print()

    print("-" * 60)
    print(f"✅ Successfully updated {success_count}/{len(module_files)} files")
    print()
    print("=" * 60)
    print("Navigation fix complete!")
    print()
    print("Changes made:")
    print("  1. Added ID attributes to all sections")
    print("  2. Converted nav buttons to anchor links")
    print("  3. Added smooth scroll behavior")
    print()
    print("Test by opening any module and clicking the nav buttons!")
    print("=" * 60)

if __name__ == '__main__':
    main()
