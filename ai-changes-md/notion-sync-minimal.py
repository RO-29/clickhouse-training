#!/usr/bin/env python3
"""
ClickHouse Training - Minimal Notion Sync
Works with just the default 'Name' column
Quick way to see results without adding all columns
"""

import os
import requests
import json
from pathlib import Path
from typing import Dict

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

MODULES = [
    {
        'number': 1,
        'name': 'Fundamentals & Architecture',
        'html_url': 'content/module-1-fundamentals.html'
    },
    {
        'number': 2,
        'name': 'Table Engines & Data Modeling',
        'html_url': 'content/module-2-table-engines.html'
    },
    {
        'number': 3,
        'name': 'Sharding Strategy & Distribution',
        'html_url': 'content/module-3-sharding.html'
    },
    {
        'number': 4,
        'name': 'Replication & High Availability',
        'html_url': 'content/module-4-replication.html'
    },
    {
        'number': 5,
        'name': 'Full Cluster Deployment',
        'html_url': 'content/module-5-cluster-deployment.html'
    },
    {
        'number': 6,
        'name': 'Query Optimization & Performance',
        'html_url': 'content/module-6-query-optimization.html'
    },
    {
        'number': 7,
        'name': 'Backup, Recovery & PITR',
        'html_url': 'content/module-7-backup-recovery.html'
    },
    {
        'number': 8,
        'name': 'Disaster Recovery & Business Continuity',
        'html_url': 'content/module-8-disaster-recovery.html'
    },
    {
        'number': 9,
        'name': 'Kafka-Based Real-Time Ingestion',
        'html_url': 'content/module-9-kafka-ingestion.html'
    },
    {
        'number': 10,
        'name': 'Migration from MongoDB/MySQL',
        'html_url': 'content/module-10-migration.html'
    }
]


def check_credentials():
    """Check if API credentials are set"""
    if not NOTION_API_KEY or not DATABASE_ID:
        print("❌ Error: Missing credentials!")
        print("\nPlease set the following environment variables:")
        print("1. NOTION_API_KEY - Your Notion integration token")
        print("2. NOTION_DATABASE_ID - Your Notion database ID")
        return False
    return True


def create_notion_page(module: Dict) -> str:
    """Create a minimal Notion page with just Name property"""

    # Minimal properties - only Name (which always exists)
    properties = {
        "Name": {
            "title": [
                {
                    "text": {
                        "content": f"Module {module['number']}: {module['name']}"
                    }
                }
            ]
        }
    }

    # Simple content
    children = [
        {
            "object": "block",
            "type": "heading_1",
            "heading_1": {
                "rich_text": [{
                    "text": {"content": f"Module {module['number']}: {module['name']}"}
                }]
            }
        },
        {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [{
                    "text": {"content": "ClickHouse Training Module"}
                }]
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
                "rich_text": [{
                    "text": {"content": "🔗 Training Link"}
                }]
            }
        },
        {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [
                    {
                        "text": {
                            "content": "View full module: ",
                            "link": None
                        }
                    },
                    {
                        "text": {
                            "content": module['html_url'],
                            "link": {"url": f"https://your-site.netlify.app/{module['html_url']}"}
                        }
                    }
                ]
            }
        }
    ]

    # Create page
    data = {
        "parent": {"database_id": DATABASE_ID},
        "properties": properties,
        "children": children
    }

    try:
        response = requests.post(
            f"{BASE_URL}/pages",
            headers=HEADERS,
            json=data
        )
        response.raise_for_status()
        page_data = response.json()
        page_url = page_data['url']

        print(f"✅ Created: Module {module['number']}: {module['name']}")
        print(f"   URL: {page_url}")
        return page_url

    except requests.exceptions.RequestException as e:
        print(f"❌ Error creating page for Module {module['number']}: {e}")
        if hasattr(e.response, 'text'):
            print(f"   Response: {e.response.text}")
        return None


def main():
    """Main function to sync modules"""

    print("=" * 60)
    print("ClickHouse Training - Minimal Notion Sync")
    print("(Works with just the default 'Name' column)")
    print("=" * 60)
    print()

    # Check credentials
    if not check_credentials():
        return

    print(f"✅ API Key: {NOTION_API_KEY[:20]}...")
    print(f"✅ Database ID: {DATABASE_ID}")
    print()

    # Test connection
    try:
        response = requests.get(
            f"{BASE_URL}/databases/{DATABASE_ID}",
            headers=HEADERS
        )
        response.raise_for_status()
        db_data = response.json()
        print(f"✅ Connected to database: {db_data['title'][0]['text']['content']}")
        print()
    except requests.exceptions.RequestException as e:
        print(f"❌ Error connecting to Notion: {e}")
        if hasattr(e, 'response') and hasattr(e.response, 'text'):
            print(f"   Response: {e.response.text}")
        return

    # Create pages
    print("Creating minimal Notion pages...")
    print("-" * 60)

    page_urls = {}
    for module in MODULES:
        url = create_notion_page(module)
        if url:
            page_urls[module['number']] = url
        print()

    print("-" * 60)
    print(f"✅ Successfully created {len(page_urls)}/{len(MODULES)} pages")
    print()

    # Save URLs
    with open('notion-page-urls.json', 'w') as f:
        json.dump(page_urls, f, indent=2)
    print("✅ Saved page URLs to notion-page-urls.json")
    print()
    print("=" * 60)
    print("Minimal sync complete!")
    print()
    print("💡 Tip: Add the 5 extra columns (Module #, Duration, Week,")
    print("    Status, Topics) to your database, then run:")
    print("    python3 notion-sync.py")
    print("    for the full experience with rich metadata!")
    print("=" * 60)


if __name__ == '__main__':
    main()
