# 🆓 Free Hosting Options for ClickHouse Training

Since GitHub Pages requires a paid plan for private repos, here are the **best free alternatives**:

---

## 🥇 Option 1: Netlify (Recommended - Easiest)

**Why Netlify:**
- ✅ **100% FREE** for private repos
- ✅ Automatic HTTPS/SSL
- ✅ Custom domains supported
- ✅ Continuous deployment from Git
- ✅ Unlimited bandwidth on free tier
- ✅ Very easy setup (5 minutes)

### Deploy to Netlify:

**Method A: Drag & Drop (Fastest - 2 minutes)**

1. Go to: https://app.netlify.com/drop
2. Drag and drop your entire `clickhouse-ks` folder
3. Done! You get a URL like: `https://random-name-123.netlify.app`
4. (Optional) Change site name in settings to: `clickhouse-training.netlify.app`

**Method B: Connect to GitHub (Better - Auto-deploys)**

1. Push your repo to GitHub as private
2. Go to: https://app.netlify.com
3. Click "Add new site" → "Import an existing project"
4. Choose "GitHub" → Authorize Netlify
5. Select `ro-29/clickhouse-training`
6. Build settings:
   - **Branch:** `main`
   - **Build command:** (leave empty)
   - **Publish directory:** `/` (root)
7. Click "Deploy site"

**Your site:** `https://clickhouse-training.netlify.app` (or custom name)

---

## 🥈 Option 2: Vercel (Great Alternative)

**Why Vercel:**
- ✅ **100% FREE** for private repos
- ✅ Automatic HTTPS/SSL
- ✅ Custom domains
- ✅ Fast global CDN
- ✅ Easy Git integration

### Deploy to Vercel:

1. Go to: https://vercel.com/new
2. Click "Import Git Repository"
3. Connect GitHub account → Select `ro-29/clickhouse-training`
4. Framework Preset: **Other** (it's a static site)
5. Root Directory: `./` (root)
6. Build command: (leave empty)
7. Output directory: (leave empty)
8. Click "Deploy"

**Your site:** `https://clickhouse-training.vercel.app`

---

## 🥉 Option 3: Cloudflare Pages (Fast CDN)

**Why Cloudflare:**
- ✅ **100% FREE** unlimited sites
- ✅ Fastest CDN in the world
- ✅ Private repo support
- ✅ Unlimited bandwidth
- ✅ Custom domains

### Deploy to Cloudflare Pages:

1. Go to: https://dash.cloudflare.com
2. Pages → "Create a project"
3. Connect to GitHub → Select `ro-29/clickhouse-training`
4. Build settings:
   - **Build command:** (leave empty)
   - **Build output directory:** `/`
   - **Root directory:** `/`
5. Click "Save and Deploy"

**Your site:** `https://clickhouse-training.pages.dev`

---

## 🎯 Option 4: Render (All-in-one)

**Why Render:**
- ✅ **100% FREE** for static sites
- ✅ Private repo support
- ✅ Auto-deploy from Git
- ✅ Custom domains

### Deploy to Render:

1. Go to: https://dashboard.render.com
2. New → "Static Site"
3. Connect GitHub → Select `ro-29/clickhouse-training`
4. Settings:
   - **Build command:** (leave empty)
   - **Publish directory:** `.` (root)
5. Click "Create Static Site"

**Your site:** `https://clickhouse-training.onrender.com`

---

## 🔧 Option 5: Two-Repo Strategy (GitHub Pages)

Keep code private, deploy to public repo.

### Setup:

**Keep private repo:** `ro-29/clickhouse-training` (all code)

**Create public repo:** `ro-29/clickhouse-training-site` (only HTML/CSS)

**Auto-deploy script:**

```bash
# Create public repo for deployment
cd "/Users/megharaizada/Desktop/Rohit Important/clickhouse-ks"

# Create deploy script
cat > deploy-public.sh << 'EOF'
#!/bin/bash
# Deploy to public GitHub Pages repo

PUBLIC_REPO="git@github.com-ro29:ro-29/clickhouse-training-site.git"
BUILD_DIR="_build"

# Clean and prepare build directory
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

# Copy only web files (not source code)
cp -r content $BUILD_DIR/
cp -r notion-guides $BUILD_DIR/
cp -r Resources $BUILD_DIR/
cp index.html $BUILD_DIR/
cp README.md $BUILD_DIR/
cp Roadmap.pdf $BUILD_DIR/

# Initialize and push to public repo
cd $BUILD_DIR
git init
git add .
git commit -m "Deploy training site"
git branch -M main
git remote add origin $PUBLIC_REPO
git push -f origin main

cd ..
rm -rf $BUILD_DIR
echo "Deployed to GitHub Pages!"
EOF

chmod +x deploy-public.sh
```

Then:
1. Create public repo: `clickhouse-training-site`
2. Run: `./deploy-public.sh`
3. Enable Pages in public repo settings
4. Site at: `https://ro-29.github.io/clickhouse-training-site/`

---

## 📊 Feature Comparison

| Platform | Free Plan | Private Repo | Custom Domain | SSL | CDN | Auto-Deploy |
|----------|-----------|--------------|---------------|-----|-----|-------------|
| **Netlify** | ✅ Unlimited | ✅ Yes | ✅ Yes | ✅ Free | ✅ Global | ✅ Yes |
| **Vercel** | ✅ Unlimited | ✅ Yes | ✅ Yes | ✅ Free | ✅ Global | ✅ Yes |
| **Cloudflare Pages** | ✅ Unlimited | ✅ Yes | ✅ Yes | ✅ Free | ✅ Best | ✅ Yes |
| **Render** | ✅ Free tier | ✅ Yes | ✅ Yes | ✅ Free | ✅ Yes | ✅ Yes |
| **GitHub Pages** | ✅ Free | ❌ No* | ✅ Yes | ✅ Free | ✅ Yes | ✅ Yes |

*Requires GitHub Pro ($4/mo) for private repos

---

## 🏆 My Recommendation

**Use Netlify** - Here's why:

1. **Easiest deployment** (drag & drop in 2 minutes)
2. **Best free tier** (unlimited bandwidth, builds)
3. **Works with private repos**
4. **Automatic HTTPS**
5. **Great documentation**
6. **No credit card required**

### Quick Netlify Setup (30 seconds):

```bash
# Install Netlify CLI (optional, for CLI deployment)
npm install -g netlify-cli

# Login and deploy
cd "/Users/megharaizada/Desktop/Rohit Important/clickhouse-ks"
netlify deploy --prod
# Follow prompts, select "Create & configure new site"
# Publish directory: . (root)
```

Or just use drag & drop at https://app.netlify.com/drop

---

## 🚀 Next Steps

**Choose your platform and follow these steps:**

### For Netlify (Recommended):
1. Go to: https://app.netlify.com/drop
2. Drag folder, done! ✅

### For Vercel:
1. Go to: https://vercel.com/new
2. Import from GitHub
3. Deploy ✅

### For Cloudflare:
1. Go to: https://dash.cloudflare.com
2. Pages → Create project
3. Deploy ✅

All three options are **100% free, support private repos, and include custom domains + SSL**.

---

**Questions?** Let me know which platform you prefer and I'll help you deploy!
