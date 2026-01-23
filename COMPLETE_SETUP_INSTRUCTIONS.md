# 🎯 Complete Setup Instructions

## ✅ What's Been Fixed

### A) ✅ HTML Content Page Links
All links in HTML pages have been fixed:
- ✅ "Quick Guide" buttons now point to the new markdown viewer
- ✅ Resource links properly configured
- ✅ Navigation between modules working

### B) 🔧 Notion Database Setup (IN PROGRESS)
Follow the steps below to set up Notion integration.

### C) 🔗 Link Notion Pages in HTML (PENDING)
Will be done after Notion setup.

### D) 📝 Markdown Renderer (✅ COMPLETE!)
Created `markdown-viewer.html` - A beautiful markdown renderer for viewing guides.

---

## 📋 Step-by-Step Guide

### Step 1: Get Your Notion API Key

Follow these instructions to get your Notion API key for **jain.rohit.2929@gmail.com**:

#### 1.1 Create Integration

1. Go to: **https://www.notion.so/my-integrations**
2. Click **"+ New integration"**
3. Fill in:
   - Name: `ClickHouse Training Integration`
   - Associated workspace: (select your workspace)
   - Capabilities: Check **Read**, **Update**, and **Insert** content
4. Click **"Submit"**
5. **COPY the "Internal Integration Token"** (starts with `secret_...`)
   - Save this somewhere safe!

#### 1.2 Create Database

1. Open **Notion** and create a new page
2. Type `/database` and select **"Table - Inline"**
3. Name it: **"ClickHouse Training Modules"**
4. Add these columns (properties):

   | Column Name | Type | Description |
   |-------------|------|-------------|
   | **Name** | Title | Module name (default) |
   | **Module #** | Number | 1-10 |
   | **Duration** | Text | "4-6 hours" |
   | **Week** | Text | "Week 1" |
   | **Status** | Select | Not Started, In Progress, Completed |
   | **Topics** | Multi-select | Tags for topics |

5. **Share database with integration:**
   - Click **"Share"** (top right)
   - Click **"Invite"**
   - Search for **"ClickHouse Training Integration"**
   - Click **"Invite"** to grant access

6. **Copy the Database ID:**
   - Your database URL looks like: `https://notion.so/workspace/XXXXX?v=YYYYY`
   - Database ID is the **XXXXX** part (32 characters)
   - Example: `1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p`

---

### Step 2: Configure Python Environment

```bash
cd "/Users/megharaizada/Desktop/Rohit Important/clickhouse-ks"

# Install Python dependencies
pip3 install -r requirements.txt

# Or install individually
pip3 install requests python-dotenv
```

---

### Step 3: Set Up Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit the .env file with your values
nano .env
# Or use any text editor
```

**In the `.env` file, replace:**
```
NOTION_API_KEY=secret_your_actual_token_here
NOTION_DATABASE_ID=your_actual_database_id_here
```

Example:
```
NOTION_API_KEY=secret_Abc123XyZ456...
NOTION_DATABASE_ID=1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p
```

---

### Step 4: Run the Notion Sync Script

```bash
# Make script executable
chmod +x notion-sync.py

# Run the sync
python3 notion-sync.py
```

**Expected Output:**
```
============================================================
ClickHouse Training - Notion Sync
============================================================

✅ API Key: secret_Abc123XyZ456...
✅ Database ID: 1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p
✅ Connected to database: ClickHouse Training Modules

Creating Notion pages...
------------------------------------------------------------
✅ Created: Module 1: Fundamentals & Architecture
   URL: https://notion.so/...

✅ Created: Module 2: Table Engines & Data Modeling
   URL: https://notion.so/...

... (continues for all 10 modules)

------------------------------------------------------------
✅ Successfully created 10/10 pages
✅ Saved page URLs to notion-page-urls.json

============================================================
Sync complete! Check your Notion database.
============================================================
```

---

### Step 5: View Your Notion Database

1. Open your Notion database
2. You should see 10 rows (one for each module)
3. Each row is clickable and contains:
   - Module title
   - Duration and week information
   - Status dropdown
   - Topic tags
   - Full content page with links

---

### Step 6: Update HTML Pages with Notion Links (Optional)

Once you have the `notion-page-urls.json` file, you can run this script to update HTML pages:

```bash
# Coming soon - will add Notion links to HTML modules
python3 update-html-with-notion.py
```

---

## 📝 Using the Markdown Viewer

The markdown viewer is now live at: **`markdown-viewer.html`**

**To use it:**

1. **Open in browser:**
   ```
   open markdown-viewer.html
   # Or deploy to Netlify and access via URL
   ```

2. **Click any module button** to view the markdown guide

3. **Or use direct links:**
   ```
   markdown-viewer.html?module=module-1-fundamentals.md
   markdown-viewer.html?module=module-2-table-engines.md
   ... etc
   ```

**Features:**
- ✅ Beautiful rendering of markdown
- ✅ Syntax highlighting for code blocks
- ✅ Properly formatted tables
- ✅ Support for emojis and ASCII art
- ✅ Responsive design for mobile
- ✅ Navigation back to home

---

## 🔍 Troubleshooting

### Issue: "Missing credentials" error

**Solution:** Make sure your `.env` file exists and contains:
```bash
NOTION_API_KEY=secret_...
NOTION_DATABASE_ID=...
```

### Issue: "Error 401 Unauthorized"

**Solution:**
- Check your API key is correct
- Verify you copied the entire token (starts with `secret_`)

### Issue: "Error 404 Not Found"

**Solution:**
- Verify Database ID is correct (32 characters)
- Ensure you **shared the database** with your integration

### Issue: "Object not found" or "Insufficient permissions"

**Solution:**
- Go to your Notion database
- Click "Share" → "Invite" → Search for your integration
- Make sure it has access

### Issue: Markdown viewer shows 404

**Solution:**
- Make sure you're viewing from the correct directory
- Or deploy to Netlify where all files are accessible

---

## 📊 What You'll Have After Setup

```
Your Notion Database:
┌─────────────────────────────────────────────────────────┐
│ Module # │ Name              │ Duration │ Week    │ Status │
├──────────┼───────────────────┼──────────┼─────────┼────────┤
│    1     │ Fundamentals...   │ 4-6 hrs  │ Week 1  │   ○    │
│    2     │ Table Engines...  │ 6-8 hrs  │ Week 1-2│   ○    │
│    3     │ Sharding...       │ 6-8 hrs  │ Week 2-3│   ○    │
│   ...    │ ...               │ ...      │ ...     │  ...   │
│   10     │ Migration...      │ 10-14hrs │ Week 7-8│   ○    │
└─────────────────────────────────────────────────────────┘
```

Each row links to a full Notion page with:
- Complete module overview
- Key topics
- Links to HTML training module
- Links to markdown guide
- (Optional) Full embedded content

---

## 🚀 Deploy Updates

Once everything is set up, deploy your updates:

```bash
# Commit changes
git add .
git commit -m "Add Notion integration and markdown viewer

- Created markdown-viewer.html for rendering guides
- Added notion-sync.py for syncing content to Notion
- Fixed all Quick Guide links in HTML modules
- Updated resource links in index.html

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Push to GitHub (if using)
git push origin main

# Netlify will auto-deploy!
```

---

## 📚 Summary of Files Created

| File | Purpose |
|------|---------|
| `markdown-viewer.html` | Renders markdown guides beautifully |
| `notion-sync.py` | Syncs content to Notion database |
| `requirements.txt` | Python dependencies |
| `.env.example` | Template for API credentials |
| `.env` | **Your actual credentials (gitignored)** |
| `notion-page-urls.json` | Saved Notion page URLs |
| `NOTION_SETUP_GUIDE.md` | Detailed Notion setup guide |
| `COMPLETE_SETUP_INSTRUCTIONS.md` | This file |

---

## ✅ Checklist

- [ ] Created Notion integration at notion.so/my-integrations
- [ ] Copied API token (starts with `secret_`)
- [ ] Created Notion database named "ClickHouse Training Modules"
- [ ] Added required columns to database
- [ ] Shared database with integration
- [ ] Copied Database ID from URL
- [ ] Installed Python dependencies (`pip3 install -r requirements.txt`)
- [ ] Created `.env` file with API key and Database ID
- [ ] Ran `python3 notion-sync.py` successfully
- [ ] Verified 10 pages created in Notion database
- [ ] Tested markdown viewer in browser
- [ ] Committed and deployed changes

---

## 🎉 You're Done!

Your ClickHouse training is now:
- ✅ Fully deployed on Netlify
- ✅ Integrated with Notion
- ✅ Has working markdown viewer
- ✅ All links fixed and functional

**Enjoy your comprehensive training platform!** 🚀

---

## ❓ Need Help?

If you encounter any issues:

1. Check the troubleshooting section above
2. Verify all credentials are correct
3. Make sure database is shared with integration
4. Check Python is installed: `python3 --version`
5. Verify dependencies: `pip3 list | grep -E "requests|dotenv"`

**Still stuck?** Double-check NOTION_SETUP_GUIDE.md for detailed instructions.
