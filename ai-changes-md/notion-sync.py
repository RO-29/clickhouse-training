#!/usr/bin/env python3
"""
ClickHouse Training - Notion Sync Script
Uploads all training modules to Notion database
"""

import os
import requests
import json
from pathlib import Path
from typing import Dict, List

# Load environment variables
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

# Module metadata
MODULES = [
    {
        'number': 1,
        'name': 'Fundamentals & Architecture',
        'duration': '4-6 hours',
        'week': 'Week 1',
        'topics': ['Architecture', 'Column Storage', 'MergeTree', 'Installation'],
        'md_file': 'notion-guides/module-1-fundamentals.md',
        'html_url': 'content/module-1-fundamentals.html'
    },
    {
        'number': 2,
        'name': 'Table Engines & Data Modeling',
        'duration': '6-8 hours',
        'week': 'Week 1-2',
        'topics': ['MergeTree Engines', 'Partitioning', 'Primary Keys', 'TTL'],
        'md_file': 'notion-guides/module-2-table-engines.md',
        'html_url': 'content/module-2-table-engines.html'
    },
    {
        'number': 3,
        'name': 'Sharding Strategy & Distribution',
        'duration': '6-8 hours',
        'week': 'Week 2-3',
        'topics': ['Distributed Tables', 'Sharding Keys', 'Query Execution'],
        'md_file': 'notion-guides/module-3-sharding.md',
        'html_url': 'content/module-3-sharding.html'
    },
    {
        'number': 4,
        'name': 'Replication & High Availability',
        'duration': '6-8 hours',
        'week': 'Week 3-4',
        'topics': ['ReplicatedMergeTree', 'Keeper', 'Failover'],
        'md_file': 'notion-guides/module-4-replication.md',
        'html_url': 'content/module-4-replication.html'
    },
    {
        'number': 5,
        'name': 'Full Cluster Deployment',
        'duration': '8-10 hours',
        'week': 'Week 4-5',
        'topics': ['Cluster Setup', 'Security', 'Monitoring', 'Network'],
        'md_file': 'notion-guides/module-5-cluster-deployment.md',
        'html_url': 'content/module-5-cluster-deployment.html'
    },
    {
        'number': 6,
        'name': 'Query Optimization & Performance',
        'duration': '6-8 hours',
        'week': 'Week 5-6',
        'topics': ['Query Pipeline', 'Indexes', 'Materialized Views', 'JOINs'],
        'md_file': 'notion-guides/module-6-query-optimization.md',
        'html_url': 'content/module-6-query-optimization.html'
    },
    {
        'number': 7,
        'name': 'Backup, Recovery & PITR',
        'duration': '4-6 hours',
        'week': 'Week 6',
        'topics': ['Backup Strategies', 'PITR', 'Restore', 'Automation'],
        'md_file': 'notion-guides/module-7-backup-recovery.md',
        'html_url': 'content/module-7-backup-recovery.html'
    },
    {
        'number': 8,
        'name': 'Disaster Recovery & Business Continuity',
        'duration': '4-6 hours',
        'week': 'Week 7',
        'topics': ['Multi-DC', 'Failover', 'RTO/RPO', 'DR Testing'],
        'md_file': 'notion-guides/module-8-disaster-recovery.md',
        'html_url': 'content/module-8-disaster-recovery.html'
    },
    {
        'number': 9,
        'name': 'Kafka-Based Real-Time Ingestion',
        'duration': '6-8 hours',
        'week': 'Week 7',
        'topics': ['Kafka Engine', 'Streaming', 'Consumer Groups', 'DLQ'],
        'md_file': 'notion-guides/module-9-kafka-ingestion.md',
        'html_url': 'content/module-9-kafka-ingestion.html'
    },
    {
        'number': 10,
        'name': 'Migration from MongoDB/MySQL',
        'duration': '10-14 hours',
        'week': 'Week 7-8',
        'topics': ['CDC', 'Debezium', 'Schema Mapping', 'Validation'],
        'md_file': 'notion-guides/module-10-migration.md',
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
        print("\nSee NOTION_SETUP_GUIDE.md for instructions.")
        return False
    return True


def create_notion_page(module: Dict) -> str:
    """Create a Notion page for a module"""

    # Read markdown content
    md_path = Path(module['md_file'])
    if not md_path.exists():
        print(f"⚠️  Warning: {md_path} not found, skipping content")
        md_content = "Content not available."
    else:
        with open(md_path, 'r', encoding='utf-8') as f:
            md_content = f.read()

    # Prepare page properties
    properties = {
        "Name": {
            "title": [
                {
                    "text": {
                        "content": f"Module {module['number']}: {module['name']}"
                    }
                }
            ]
        },
        "Module #": {
            "number": module['number']
        },
        "Duration": {
            "rich_text": [
                {
                    "text": {
                        "content": module['duration']
                    }
                }
            ]
        },
        "Week": {
            "rich_text": [
                {
                    "text": {
                        "content": module['week']
                    }
                }
            ]
        },
        "Status": {
            "select": {
                "name": "Not Started"
            }
        },
        "Topics": {
            "multi_select": [
                {"name": topic} for topic in module['topics']
            ]
        }
    }

    # Create children blocks (content)
    children = [
        {
            "object": "block",
            "type": "heading_1",
            "heading_1": {
                "rich_text": [{"text": {"content": f"Module {module['number']}: {module['name']}"}}]
            }
        },
        {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [
                    {"text": {"content": f"Duration: {module['duration']} | {module['week']}"}}
                ]
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
                "rich_text": [{"text": {"content": "📋 Content"}}]
            }
        },
        {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [
                    {
                        "text": {
                            "content": "See the full markdown guide for detailed content, diagrams, and examples.",
                            "link": None
                        }
                    }
                ]
            }
        },
        {
            "object": "block",
            "type": "heading_2",
            "heading_2": {
                "rich_text": [{"text": {"content": "🔗 Links"}}]
            }
        },
        {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [
                    {"text": {"content": "HTML Training Module: "}},
                    {"text": {"content": module['html_url'], "link": {"url": f"https://your-site.netlify.app/{module['html_url']}"}}}
                ]
            }
        },
        {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [
                    {"text": {"content": "Markdown Guide: "}},
                    {"text": {"content": module['md_file']}}
                ]
            }
        }
    ]

    # Create page in database
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
        page_id = page_data['id']
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
    """Main function to sync all modules to Notion"""

    print("=" * 60)
    print("ClickHouse Training - Notion Sync")
    print("=" * 60)
    print()

    # Check credentials
    if not check_credentials():
        return

    print(f"✅ API Key: {NOTION_API_KEY[:20]}...")
    print(f"✅ Database ID: {DATABASE_ID}")
    print()

    # Test API connection
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

    # Create pages for each module
    print("Creating Notion pages...")
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

    # Save URLs to file
    with open('notion-page-urls.json', 'w') as f:
        json.dump(page_urls, f, indent=2)
    print("✅ Saved page URLs to notion-page-urls.json")
    print()
    print("=" * 60)
    print("Sync complete! Check your Notion database.")
    print("=" * 60)


if __name__ == '__main__':
    main()
