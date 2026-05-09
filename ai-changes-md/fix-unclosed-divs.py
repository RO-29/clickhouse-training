#!/usr/bin/env python3
"""
Fix Unclosed Divs in HTML Modules
Adds missing </div> tags to properly close sections
"""

import re
from pathlib import Path

def fix_unclosed_divs(html_path: Path) -> bool:
    """Fix unclosed divs in a single HTML module"""

    print(f"\nProcessing: {html_path.name}")

    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Count current divs
    opening_count = content.count('<div')
    closing_count = content.count('</div>')
    print(f"  Current: {opening_count} opening, {closing_count} closing")

    if opening_count == closing_count:
        print(f"  ✓ Already balanced!")
        return False

    # Find all section blocks and ensure each one is properly closed
    # Pattern: <div class="section"...> ... content ... </div>
    # We need to find sections that don't have proper closing

    # Strategy: Find each "<!-- ... Section -->" comment and ensure
    # the section that follows it is properly closed before the next section comment

    # Find all section comments
    section_comments = list(re.finditer(r'<!-- .*? Section -->', content))

    fixed_content = content

    # For each section (except the last), ensure it's closed before the next section
    for i in range(len(section_comments) - 1):
        current_section_end = section_comments[i].end()
        next_section_start = section_comments[i + 1].start()

        # Get the content between this section and the next
        between = content[current_section_end:next_section_start]

        # Count divs in this section
        section_opening = between.count('<div')
        section_closing = between.count('</div>')

        if section_opening > section_closing:
            # Need to add closing divs
            missing = section_opening - section_closing
            # Add the missing closing divs before the next section comment
            insert_pos = next_section_start
            closing_divs = '\n    </div>\n' * missing
            fixed_content = fixed_content[:insert_pos] + closing_divs + fixed_content[insert_pos:]
            print(f"  Added {missing} closing divs before next section")

    # Handle the last section (Resources section)
    # It should close before the footer
    last_section_start = section_comments[-1].end()

    # Find the closing container div (</div> followed by footer or bottom nav)
    footer_match = re.search(r'<div style="background: #333.*?ClickHouse Knowledge Transfer', fixed_content[last_section_start:])
    if footer_match:
        footer_pos = last_section_start + footer_match.start()

        # Count divs between last section and footer
        last_section_content = fixed_content[last_section_start:footer_pos]
        section_opening = last_section_content.count('<div')
        section_closing = last_section_content.count('</div>')

        if section_opening > section_closing:
            missing = section_opening - section_closing
            closing_divs = '\n    </div>\n' * missing
            fixed_content = fixed_content[:footer_pos] + closing_divs + fixed_content[footer_pos:]
            print(f"  Added {missing} closing divs before footer")

    # Verify final counts
    final_opening = fixed_content.count('<div')
    final_closing = fixed_content.count('</div>')
    print(f"  Final: {final_opening} opening, {final_closing} closing")

    if final_opening == final_closing:
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print(f"  ✅ Fixed! Balanced divs")
        return True
    else:
        print(f"  ⚠️  Still unbalanced (difference: {final_opening - final_closing})")
        # Save anyway, it's better than before
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        return True

def main():
    """Fix unclosed divs in all modules"""

    print("=" * 60)
    print("Fix Unclosed Divs in HTML Modules")
    print("=" * 60)

    content_dir = Path('content')
    module_files = sorted(content_dir.glob('module-*.html'))

    if not module_files:
        print("❌ Error: No module files found")
        return

    print(f"\nFound {len(module_files)} module files")

    success_count = 0
    for html_path in module_files:
        if fix_unclosed_divs(html_path):
            success_count += 1

    print("\n" + "-" * 60)
    print(f"✅ Processed {success_count}/{len(module_files)} files")
    print("=" * 60)

if __name__ == '__main__':
    main()
