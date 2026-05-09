# 🔧 Notion API Setup Guide

## 📋 How to Get Your Notion API Key

Follow these steps to get your Notion API key for **jain.rohit.2929@gmail.com**:

### Step 1: Create a Notion Integration

1. **Go to Notion Integrations page:**
   ```
   https://www.notion.so/my-integrations
   ```

2. **Click "New integration"** (or "+ Create new integration")

3. **Fill in the details:**
   - **Name:** `ClickHouse Training Integration`
   - **Associated workspace:** Select your workspace
   - **Logo:** (Optional)
   - **Capabilities:** Check these permissions:
     - ✅ Read content
     - ✅ Update content
     - ✅ Insert content

4. **Click "Submit"**

5. **Copy the "Internal Integration Token"** (starts with `secret_...`)
   - This is your API key!
   - Keep it safe and don't share it publicly

### Step 2: Create a Database in Notion

1. **Open Notion** and create a new page

2. **Create a database:**
   - Type `/database` and select "Table - Inline"
   - Name it: **"ClickHouse Training Modules"**

3. **Set up columns:**
   - **Name** (Title) - Module name
   - **Module #** (Number) - Module number (1-10)
   - **Duration** (Text) - e.g., "4-6 hours"
   - **Week** (Text) - e.g., "Week 1"
   - **Status** (Select) - Not Started, In Progress, Completed
   - **Topics** (Multi-select) - Key topics covered
   - **Content** (Text) - Link to content or embedded content

4. **Share the database with your integration:**
   - Click "Share" button (top right)
   - Click "Invite"
   - Search for "ClickHouse Training Integration"
   - Click "Invite"

5. **Copy the Database ID:**
   - Your database URL looks like: `https://notion.so/workspace/XXXXX?v=YYYYY`
   - The Database ID is the `XXXXX` part (32 characters)

### Step 3: Provide the Information

Once you have these, provide me with:

1. **Notion API Key** (Integration Token)
   ```
   Format: secret_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```

2. **Database ID**
   ```
   Format: 32 character string (e.g., 1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p)
   ```

---

## 🔐 Security Note

- Your API key is sensitive - treat it like a password
- Don't commit it to Git or share publicly
- We'll store it in a `.env` file (which is gitignored)

---

## 📝 What We'll Do Next

Once you provide the API key and Database ID, I'll:

1. ✅ Create a Python script to populate your Notion database
2. ✅ Upload all 10 modules as Notion pages
3. ✅ Add proper formatting, diagrams, and links
4. ✅ Update HTML pages to link to Notion pages
5. ✅ Create a markdown renderer for viewing .md files

---

## 🎯 Expected Result

Your Notion database will look like this:

| Name | Module # | Duration | Week | Status | Topics |
|------|----------|----------|------|--------|--------|
| Fundamentals & Architecture | 1 | 4-6 hours | Week 1 | Not Started | Architecture, Storage, MergeTree |
| Table Engines & Data Modeling | 2 | 6-8 hours | Week 1-2 | Not Started | Engines, Partitioning, TTL |
| ... | ... | ... | ... | ... | ... |

Each row will link to a full Notion page with:
- Complete module content
- Architecture diagrams
- Code examples
- Best practices
- Resources

---

## ❓ Need Help?

If you have any issues:
1. Make sure you're logged into the correct Notion account
2. Verify the integration has proper permissions
3. Ensure the database is shared with the integration
4. Check that the Database ID is correct

---

**Ready to proceed?** Get your API key and Database ID, and I'll set everything up! 🚀
