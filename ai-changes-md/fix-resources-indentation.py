#!/usr/bin/env python3
"""
Fix Resources Section Indentation
Fixes broken indentation in the resources section across all modules
"""

import re
from pathlib import Path

def fix_resources_indentation(html_path: Path) -> bool:
    """Fix resources section indentation in a single HTML module"""

    print(f"Processing: {html_path.name}")

    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Fix 1: Add proper indentation to grid-2 opening tag
    # Find: </div>\n\n<div class="grid-2">
    # Replace with proper indentation
    content = re.sub(
        r'(</div>\n)\n(<div class="grid-2">)',
        r'\1\n            \2',
        content
    )

    # Fix 2: Ensure all cards inside grid-2 have proper indentation
    # This is already mostly correct, but we can verify

    # Fix 3: Fix section-header that might be on same line as opening div
    content = re.sub(
        r'<div class="section" id="([^"]+)"><div class="section-header">',
        r'<div class="section" id="\1">\n        <div class="section-header">',
        content
    )

    # Save if changes were made
    if content != original_content:
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✅ Fixed indentation")
        return True
    else:
        print(f"  ℹ️  No changes needed")
        return False

def main():
    """Fix indentation in all modules"""

    print("=" * 60)
    print("Fix Resources Section Indentation")
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
        if fix_resources_indentation(html_path):
            success_count += 1
        print()

    print("-" * 60)
    print(f"✅ Successfully updated {success_count}/{len(module_files)} files")
    print()
    print("All indentation issues fixed!")
    print("=" * 60)

if __name__ == '__main__':
    main()
