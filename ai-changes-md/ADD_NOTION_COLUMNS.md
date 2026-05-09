# 📋 How to Add Columns to Your Notion Database

Your database is connected but needs 5 more columns. This takes about 2 minutes.

## 🎯 Quick Visual Guide

```
Your Notion Database Table:
┌─────────────────────────────────────────────────────────────┐
│ Name (title) │ + Add Column                                 │
├──────────────┼──────────────────────────────────────────────┤
│              │                                              │
└──────────────┴──────────────────────────────────────────────┘
                ↑
        Click this + to add columns
```

---

## ✅ Step-by-Step: Add Each Column

### 1️⃣ Add "Module #" Column

1. Click the **'+'** button at the top right of your table
2. Type: `Module #`
3. Click the type dropdown
4. Select: **Number**
5. Press Enter

```
Result:
┌──────────┬───────────┐
│ Name     │ Module #  │
├──────────┼───────────┤
│          │           │
└──────────┴───────────┘
```

---

### 2️⃣ Add "Duration" Column

1. Click the **'+'** button again
2. Type: `Duration`
3. Click the type dropdown
4. Select: **Text**
5. Press Enter

```
Result:
┌──────────┬───────────┬──────────┐
│ Name     │ Module #  │ Duration │
├──────────┼───────────┼──────────┤
│          │           │          │
└──────────┴───────────┴──────────┘
```

---

### 3️⃣ Add "Week" Column

1. Click the **'+'** button again
2. Type: `Week`
3. Click the type dropdown
4. Select: **Text**
5. Press Enter

```
Result:
┌──────────┬───────────┬──────────┬────────┐
│ Name     │ Module #  │ Duration │ Week   │
├──────────┼───────────┼──────────┼────────┤
│          │           │          │        │
└──────────┴───────────┴──────────┴────────┘
```

---

### 4️⃣ Add "Status" Column

1. Click the **'+'** button again
2. Type: `Status`
3. Click the type dropdown
4. Select: **Select** (NOT Multi-select!)
5. Press Enter

```
Result:
┌──────────┬───────────┬──────────┬────────┬────────┐
│ Name     │ Module #  │ Duration │ Week   │ Status │
├──────────┼───────────┼──────────┼────────┼────────┤
│          │           │          │        │   ○    │
└──────────┴───────────┴──────────┴────────┴────────┘
```

---

### 5️⃣ Add "Topics" Column

1. Click the **'+'** button again
2. Type: `Topics`
3. Click the type dropdown
4. Select: **Multi-select** (NOT Select!)
5. Press Enter

```
Final Result:
┌──────────┬───────────┬──────────┬────────┬────────┬────────┐
│ Name     │ Module #  │ Duration │ Week   │ Status │ Topics │
├──────────┼───────────┼──────────┼────────┼────────┼────────┤
│          │           │          │        │   ○    │        │
└──────────┴───────────┴──────────┴────────┴────────┴────────┘
```

---

## ✅ Verify Your Setup

After adding all columns, run this command to verify:

```bash
python3 check-notion-database.py
```

**Expected output:**
```
✅ All required properties exist!
You can now run: python3 notion-sync.py
```

---

## 📸 Property Types Reference

| Column Name | Notion Type | What It Looks Like in Dropdown |
|-------------|-------------|-------------------------------|
| Module #    | Number      | `123` icon |
| Duration    | Text        | `T` icon |
| Week        | Text        | `T` icon |
| Status      | Select      | Single tag icon |
| Topics      | Multi-select| Multiple tags icon |

---

## 🎯 Quick Checklist

- [ ] Module # added (type: Number)
- [ ] Duration added (type: Text)
- [ ] Week added (type: Text)
- [ ] Status added (type: Select)
- [ ] Topics added (type: Multi-select)
- [ ] Verified with `python3 check-notion-database.py`
- [ ] Ready to run `python3 notion-sync.py`

---

## ❓ Common Issues

### "I can't find the + button"
- Make sure you're in **Table view** (not Gallery/List)
- The + appears in the header row, to the right of existing columns
- Try scrolling the table to the right if you have a narrow screen

### "I added a column but sync still fails"
- Make sure you selected the EXACT type listed above
- "Select" and "Multi-select" are different!
- "Text" is also called "Rich Text" in some Notion versions

### "I want to skip some columns"
- All 5 columns are required for the sync script to work
- If you want a minimal version, let me know and I can create a simpler script

---

## 🚀 What Happens After You Add Columns?

Once you add all columns and run `notion-sync.py`, you'll get:

```
✅ Created: Module 1: Fundamentals & Architecture
   Module #: 1
   Duration: 4-6 hours
   Week: Week 1
   Status: Not Started
   Topics: Architecture, Column Storage, MergeTree, Installation

✅ Created: Module 2: Table Engines & Data Modeling
...
✅ Successfully created 10/10 pages
```

Your Notion database will then have 10 fully populated rows, each linking to detailed module content!

---

**Ready?** Add the 5 columns now, then run:
```bash
python3 check-notion-database.py    # Verify
python3 notion-sync.py              # Sync!
```
