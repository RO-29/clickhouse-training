#!/usr/bin/env python3
"""
Check Notion Database Properties
Shows what columns exist in your database and what's missing
"""

import os
import requests
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

REQUIRED_PROPERTIES = {
    'Name': 'title',
    'Module #': 'number',
    'Duration': 'rich_text',
    'Week': 'rich_text',
    'Status': 'select',
    'Topics': 'multi_select'
}

def main():
    print("=" * 60)
    print("Notion Database Property Checker")
    print("=" * 60)
    print()

    if not NOTION_API_KEY or not DATABASE_ID:
        print("❌ Error: Missing credentials!")
        print("Please check your .env file.")
        return

    try:
        response = requests.get(
            f"{BASE_URL}/databases/{DATABASE_ID}",
            headers=HEADERS
        )
        response.raise_for_status()
        db_data = response.json()

        print(f"✅ Connected to database: {db_data['title'][0]['text']['content']}")
        print()

        # Get existing properties
        existing_props = db_data.get('properties', {})

        print("📊 Current Properties in Your Database:")
        print("-" * 60)
        for prop_name, prop_data in existing_props.items():
            prop_type = prop_data.get('type', 'unknown')
            print(f"  ✅ {prop_name} ({prop_type})")
        print()

        # Check for missing properties
        print("🔍 Required Properties Check:")
        print("-" * 60)
        missing = []
        for prop_name, prop_type in REQUIRED_PROPERTIES.items():
            if prop_name in existing_props:
                actual_type = existing_props[prop_name].get('type')
                if actual_type == prop_type:
                    print(f"  ✅ {prop_name} ({prop_type}) - OK")
                else:
                    print(f"  ⚠️  {prop_name} exists but wrong type (expected: {prop_type}, got: {actual_type})")
                    missing.append(prop_name)
            else:
                print(f"  ❌ {prop_name} ({prop_type}) - MISSING")
                missing.append(prop_name)
        print()

        if missing:
            print("=" * 60)
            print("⚠️  ACTION REQUIRED: Add Missing Properties")
            print("=" * 60)
            print()
            print("Please add these columns to your Notion database:")
            print()
            for prop_name in missing:
                prop_type = REQUIRED_PROPERTIES[prop_name]
                print(f"  📌 {prop_name}")
                print(f"     Type: {prop_type}")
                print()

            print("How to add properties in Notion:")
            print("1. Open your database in Notion")
            print("2. Click the '+' button in the top right of the table")
            print("3. For each property:")
            print("   - Type the property name (e.g., 'Module #')")
            print("   - Select the type from dropdown:")
            print("     • Module # → Number")
            print("     • Duration → Text")
            print("     • Week → Text")
            print("     • Status → Select")
            print("     • Topics → Multi-select")
            print()
            print("After adding properties, run this script again to verify.")
            print()
        else:
            print("=" * 60)
            print("✅ All required properties exist!")
            print("=" * 60)
            print()
            print("You can now run: python3 notion-sync.py")
            print()

    except requests.exceptions.RequestException as e:
        print(f"❌ Error: {e}")
        if hasattr(e, 'response') and hasattr(e.response, 'text'):
            print(f"Response: {e.response.text}")

if __name__ == '__main__':
    main()
