#!/usr/bin/env python3
"""
Fix Resources Section Layout
Moves Notion card outside the grid for better layout
"""

import re
from pathlib import Path

def fix_resources_layout(html_path: Path) -> bool:
    """Fix resources section layout in a single HTML module"""

    print(f"Processing: {html_path.name}")

    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Pattern to find the Notion card inside grid-2
    notion_card_pattern = r'(<div class="grid-2">)\s*(<div class="card">\s*<h4>📘 View in Notion</h4>.*?</div>)\s*'

    # Check if Notion card exists in grid
    if not re.search(notion_card_pattern, content, re.DOTALL):
        print(f"  ℹ️  No Notion card in grid or already fixed")
        return False

    # Extract the Notion card
    match = re.search(notion_card_pattern, content, re.DOTALL)
    if not match:
        return False

    notion_card = match.group(2)

    # Remove Notion card from grid
    content = re.sub(
        notion_card_pattern,
        r'\1\n            ',
        content,
        count=1,
        flags=re.DOTALL
    )

    # Create a prominent Notion section to add before the grid
    notion_section = '''
            <!-- Notion Integration -->
            <div style="background: linear-gradient(135deg, #ff6b35 0%, #f7931e 100%); padding: 25px; border-radius: 12px; margin-bottom: 30px; text-align: center;">
                <h3 style="margin: 0 0 15px 0; color: white; font-size: 1.4em;">📘 Track Your Progress in Notion</h3>
                <p style="color: white; margin: 0 0 20px 0; opacity: 0.95;">Access this module in your Notion workspace for note-taking, progress tracking, and collaboration.</p>
                <a href="NOTION_URL_PLACEHOLDER" target="_blank" rel="noopener noreferrer" style="display: inline-block; background: white; color: #ff6b35; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 1.1em; transition: transform 0.2s;" onmouseover="this.style.transform='scale(1.05)'" onmouseout="this.style.transform='scale(1)'">Open in Notion →</a>
            </div>

'''

    # Extract the Notion URL from the card
    url_match = re.search(r'href="(https://www\.notion\.so/[^"]+)"', notion_card)
    if url_match:
        notion_url = url_match.group(1)
        notion_section = notion_section.replace('NOTION_URL_PLACEHOLDER', notion_url)

    # Insert the new Notion section before the grid-2
    pattern_before_grid = r'(<div class="section-header">(?:📚\s*)?.*Resources.*</div>\s*<div class="section-content">\s*)'

    content = re.sub(
        pattern_before_grid,
        r'\1' + notion_section,
        content,
        count=1,
        flags=re.DOTALL | re.IGNORECASE
    )

    # Save if changes were made
    if content != original_content:
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✅ Fixed layout - Notion card now prominent above grid")
        return True
    else:
        print(f"  ℹ️  No changes needed")
        return False

def main():
    """Fix layout in all modules"""

    print("=" * 60)
    print("Fix Resources Section Layout")
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
        if fix_resources_layout(html_path):
            success_count += 1
        print()

    print("-" * 60)
    print(f"✅ Successfully updated {success_count}/{len(module_files)} files")
    print()
    print("Resources section now has:")
    print("  • Prominent Notion card above the grid")
    print("  • Clean 2x2 grid layout (4 cards)")
    print("  • Better visual hierarchy")
    print("=" * 60)

if __name__ == '__main__':
    main()
