#!/usr/bin/env python3
"""
ClickHouse Training - Update HTML with Notion Links
Adds Notion page links to HTML module files
"""

import json
import re
from pathlib import Path
from typing import Dict

def load_notion_urls() -> Dict[int, str]:
    """Load Notion page URLs from JSON file"""
    json_path = Path('notion-page-urls.json')

    if not json_path.exists():
        print("❌ Error: notion-page-urls.json not found!")
        print("\nPlease run notion-sync.py first to create Notion pages.")
        return {}

    with open(json_path, 'r') as f:
        urls = json.load(f)

    # Convert string keys to integers
    return {int(k): v for k, v in urls.items()}


def update_html_file(module_number: int, notion_url: str) -> bool:
    """Update a single HTML file with Notion link"""

    html_path = Path(f'content/module-{module_number}-*.html')
    html_files = list(Path('content').glob(f'module-{module_number}-*.html'))

    if not html_files:
        print(f"⚠️  Warning: HTML file for Module {module_number} not found")
        return False

    html_path = html_files[0]

    # Read the HTML file
    with open(html_path, 'r', encoding='utf-8') as f:
        html_content = f.read()

    # Check if Notion link already exists
    if 'View in Notion' in html_content or notion_url in html_content:
        print(f"ℹ️  Module {module_number}: Notion link already exists, skipping")
        return True

    # Find the resources section grid and add Notion card
    # We'll add it as the first card in the grid-2 div

    notion_card_html = f'''
                <div class="card">
                    <h4>📘 View in Notion</h4>
                    <p style="margin: 10px 0;">Access this module in your Notion workspace for note-taking and tracking your progress.</p>
                    <a href="{notion_url}" target="_blank" rel="noopener noreferrer" style="color: #ff6b35; font-weight: 600; text-decoration: none;">Open in Notion →</a>
                </div>
'''

    # Pattern to match the grid-2 div in Resources section
    # Flexible pattern to match any Resources-related section header
    # Allows for optional h3 tags between section-content and grid-2
    grid_pattern = r'(<div class="section-header">(?:📚\s*)?.*Resources.*</div>\s*<div class="section-content">\s*(?:<h3>.*?</h3>\s*)?<div class="grid-2">)'

    updated_content = re.sub(
        grid_pattern,
        r'\1' + notion_card_html,
        html_content,
        count=1,
        flags=re.DOTALL | re.IGNORECASE
    )

    # Save the updated file
    if updated_content != html_content:
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(updated_content)
        print(f"✅ Module {module_number}: Added Notion link")
        return True
    else:
        print(f"⚠️  Module {module_number}: Could not find insertion point")
        return False


def main():
    """Main function to update all HTML files"""

    print("=" * 60)
    print("ClickHouse Training - Update HTML with Notion Links")
    print("=" * 60)
    print()

    # Load Notion URLs
    notion_urls = load_notion_urls()

    if not notion_urls:
        return

    print(f"✅ Loaded {len(notion_urls)} Notion page URLs")
    print()

    # Update each HTML file
    print("Updating HTML files...")
    print("-" * 60)

    success_count = 0
    for module_number in sorted(notion_urls.keys()):
        notion_url = notion_urls[module_number]
        if update_html_file(module_number, notion_url):
            success_count += 1

    print("-" * 60)
    print(f"✅ Successfully updated {success_count}/{len(notion_urls)} HTML files")
    print()
    print("=" * 60)
    print("Update complete! All HTML files now link to Notion pages.")
    print("=" * 60)


if __name__ == '__main__':
    main()
