#!/usr/bin/env python3
"""
Update Notion Pages with Markdown Content Links
Adds prominent links to markdown viewer for each module
"""

import os
import requests
import json
from dotenv import load_dotenv

load_dotenv()

NOTION_API_KEY = os.getenv('NOTION_API_KEY', '')
DATABASE_ID = os.getenv('NOTION_DATABASE_ID', '')

NOTION_VERSION = '2022-06-28'
BASE_URL = 'https://api.notion.com/v1'

HEADERS = {
    'Authorization': f'Bearer {NOTION_API_KEY}',
    'Content-Type': 'application/json',
    'Notion-Version': NOTION_VERSION
}

# Module metadata with Netlify URL
NETLIFY_URL = "https://your-site.netlify.app"  # Update this with your actual Netlify URL

MODULES = [
    {'number': 1, 'name': 'Fundamentals & Architecture', 'md_file': 'module-1-fundamentals.md'},
    {'number': 2, 'name': 'Table Engines & Data Modeling', 'md_file': 'module-2-table-engines.md'},
    {'number': 3, 'name': 'Sharding Strategy & Distribution', 'md_file': 'module-3-sharding.md'},
    {'number': 4, 'name': 'Replication & High Availability', 'md_file': 'module-4-replication.md'},
    {'number': 5, 'name': 'Full Cluster Deployment', 'md_file': 'module-5-cluster-deployment.md'},
    {'number': 6, 'name': 'Query Optimization & Performance', 'md_file': 'module-6-query-optimization.md'},
    {'number': 7, 'name': 'Backup, Recovery & PITR', 'md_file': 'module-7-backup-recovery.md'},
    {'number': 8, 'name': 'Disaster Recovery & Business Continuity', 'md_file': 'module-8-disaster-recovery.md'},
    {'number': 9, 'name': 'Kafka-Based Real-Time Ingestion', 'md_file': 'module-9-kafka-ingestion.md'},
    {'number': 10, 'name': 'Migration from MongoDB/MySQL', 'md_file': 'module-10-migration.md'}
]

def load_page_urls():
    """Load page URLs from JSON"""
    try:
        with open('notion-page-urls.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print("❌ Error: notion-page-urls.json not found")
        print("Please run notion-sync.py first!")
        return None

def get_page_id_from_url(url):
    """Extract page ID from Notion URL"""
    # URL format: https://notion.so/Page-Title-1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p
    # Page ID is the last 32 characters (without hyphens)
    page_id = url.split('-')[-1].split('?')[0]
    # Add hyphens to format as UUID
    if len(page_id) == 32:
        return f"{page_id[:8]}-{page_id[8:12]}-{page_id[12:16]}-{page_id[16:20]}-{page_id[20:]}"
    return page_id

def get_page_children(page_id):
    """Get all blocks (children) of a page"""
    try:
        response = requests.get(
            f"{BASE_URL}/blocks/{page_id}/children",
            headers=HEADERS
        )
        response.raise_for_status()
        return response.json()['results']
    except requests.exceptions.RequestException as e:
        print(f"Error fetching children: {e}")
        return None

def delete_block(block_id):
    """Delete a block"""
    try:
        response = requests.delete(
            f"{BASE_URL}/blocks/{block_id}",
            headers=HEADERS
        )
        response.raise_for_status()
        return True
    except requests.exceptions.RequestException:
        return False

def append_blocks_to_page(page_id, blocks):
    """Append new blocks to a page"""
    try:
        response = requests.patch(
            f"{BASE_URL}/blocks/{page_id}/children",
            headers=HEADERS,
            json={"children": blocks}
        )
        response.raise_for_status()
        return True
    except requests.exceptions.RequestException as e:
        print(f"Error appending blocks: {e}")
        if hasattr(e, 'response'):
            print(f"Response: {e.response.text}")
        return False

def update_page_content(module, page_url):
    """Update a Notion page with markdown viewer link"""

    print(f"\nUpdating Module {module['number']}: {module['name']}")

    page_id = get_page_id_from_url(page_url)
    print(f"  Page ID: {page_id}")

    # Get existing children
    children = get_page_children(page_id)
    if children is None:
        print("  ❌ Could not fetch page content")
        return False

    # Delete old content blocks (keep first 3: title, duration, divider)
    deleted_count = 0
    for i, block in enumerate(children[3:], start=3):  # Skip first 3 blocks
        if delete_block(block['id']):
            deleted_count += 1

    print(f"  🗑️  Removed {deleted_count} old content blocks")

    # Create new content blocks
    markdown_url = f"{NETLIFY_URL}/markdown-viewer.html?module={module['md_file']}"

    new_blocks = [
        {
            "object": "block",
            "type": "heading_2",
            "heading_2": {
                "rich_text": [{"text": {"content": "📖 Start Learning"}}],
                "color": "orange"
            }
        },
        {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [
                    {"text": {"content": "View the complete training guide with diagrams, code examples, and exercises:", "link": None}},
                ]
            }
        },
        {
            "object": "block",
            "type": "bookmark",
            "bookmark": {
                "url": markdown_url
            }
        },
        {
            "object": "block",
            "type": "divider",
            "divider": {}
        },
        {
            "object": "block",
            "type": "heading_2",
            "heading_2": {
                "rich_text": [{"text": {"content": "📝 Quick Guide"}}],
                "color": "blue"
            }
        },
        {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [
                    {"text": {"content": "The markdown guide includes:", "link": None}},
                ]
            }
        },
        {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [{"text": {"content": "Concise theory and concepts"}}]
            }
        },
        {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [{"text": {"content": "ASCII architecture diagrams"}}]
            }
        },
        {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [{"text": {"content": "Code examples and configurations"}}]
            }
        },
        {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [{"text": {"content": "Best practices and troubleshooting"}}]
            }
        },
        {
            "object": "block",
            "type": "divider",
            "divider": {}
        },
        {
            "object": "block",
            "type": "heading_2",
            "heading_2": {
                "rich_text": [{"text": {"content": "💡 How to Use This Module"}}],
                "color": "green"
            }
        },
        {
            "object": "block",
            "type": "numbered_list_item",
            "numbered_list_item": {
                "rich_text": [{"text": {"content": "Click the bookmark above to open the markdown guide"}}]
            }
        },
        {
            "object": "block",
            "type": "numbered_list_item",
            "numbered_list_item": {
                "rich_text": [{"text": {"content": "Follow along with the examples and exercises"}}]
            }
        },
        {
            "object": "block",
            "type": "numbered_list_item",
            "numbered_list_item": {
                "rich_text": [{"text": {"content": "Add your notes below this section"}}]
            }
        },
        {
            "object": "block",
            "type": "numbered_list_item",
            "numbered_list_item": {
                "rich_text": [{"text": {"content": "Update the Status column when complete"}}]
            }
        }
    ]

    # Append new blocks
    if append_blocks_to_page(page_id, new_blocks):
        print(f"  ✅ Added markdown viewer link and instructions")
        return True
    else:
        print(f"  ❌ Failed to update content")
        return False

def main():
    """Update all Notion pages"""

    print("=" * 60)
    print("Update Notion Pages with Markdown Content")
    print("=" * 60)
    print()

    if not NOTION_API_KEY or not DATABASE_ID:
        print("❌ Error: Missing credentials")
        return

    # Load page URLs
    page_urls = load_page_urls()
    if not page_urls:
        return

    print(f"✅ Loaded {len(page_urls)} page URLs")

    # Ask for Netlify URL
    print()
    print("Enter your Netlify URL (or press Enter to use placeholder):")
    netlify_input = input("> ").strip()
    if netlify_input:
        global NETLIFY_URL
        NETLIFY_URL = netlify_input.rstrip('/')

    print(f"\nUsing URL: {NETLIFY_URL}")
    print()
    print("-" * 60)

    # Update each page
    success_count = 0
    for module in MODULES:
        module_num_str = str(module['number'])
        if module_num_str in page_urls:
            if update_page_content(module, page_urls[module_num_str]):
                success_count += 1

    print()
    print("-" * 60)
    print(f"✅ Successfully updated {success_count}/{len(MODULES)} pages")
    print()
    print("=" * 60)
    print("Update complete!")
    print()
    print("Each Notion page now has:")
    print("  • Prominent link to markdown viewer")
    print("  • Instructions on how to use the module")
    print("  • Space for your personal notes")
    print("=" * 60)

if __name__ == '__main__':
    main()
