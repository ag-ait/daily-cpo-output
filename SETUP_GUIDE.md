# GitHub Actions Setup - Quick Start Guide

Follow these steps in order. Should take ~30 minutes total.

---

## ⚠️ Before You Start

Make sure you have:
- [ ] GitHub account (free)
- [ ] Anthropic API key (get from https://console.anthropic.com/settings/keys)
- [ ] Current system working (test: `~/cpo-output/orchestrator.sh`)

---

## 📋 Step-by-Step Setup

### STEP 1: Get Anthropic API Key (5 minutes)

**Why:** GitHub Actions needs direct API access to Claude (different from CLI)

1. Go to https://console.anthropic.com/settings/keys
2. Click "Create Key"
3. Name it: "Daily CPO Output - GitHub Actions"
4. Copy the key (starts with `sk-ant-...`)
5. Save it somewhere safe temporarily

**Cost:** First $5 free, then ~$0.50/month for these briefs

---

### STEP 2: Prepare Your Secrets (5 minutes)

Run this helper script on your laptop:

```bash
cd ~/cpo-output/github-migration
./prepare-secrets.sh
```

This will output all your secrets ready to copy-paste into GitHub.

**Save the output** - you'll need it in Step 4.

---

### STEP 3: Create GitHub Repository (5 minutes)

1. Go to https://github.com/new

2. Fill in:
   - Repository name: `daily-cpo-output`
   - Description: "Automated daily brief delivery system"
   - **Privacy: Private** ⚠️ IMPORTANT
   - Skip "Initialize with README" (we have files already)

3. Click "Create repository"

4. Follow the instructions for "push an existing repository":

```bash
cd ~/cpo-output/github-migration
git init
git add .
git commit -m "Initial commit: Daily CPO Output automation"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/daily-cpo-output.git
git push -u origin main
```

Replace `YOUR_USERNAME` with your GitHub username.

---

### STEP 4: Configure Secrets (10 minutes)

1. Go to your repository on GitHub
2. Click **Settings** tab
3. Click **Secrets and variables** → **Actions**
4. Click **New repository secret**

Add each secret:

#### Secret 1: RESEND_API_KEY
- Name: `RESEND_API_KEY`
- Value: (from `prepare-secrets.sh` output)
- Click "Add secret"

#### Secret 2: NEWS_API_KEY
- Name: `NEWS_API_KEY`
- Value: (from `prepare-secrets.sh` output)
- Click "Add secret"

#### Secret 3: CLAUDE_API_KEY
- Name: `CLAUDE_API_KEY`
- Value: (the API key you got in Step 1)
- Click "Add secret"

#### Secret 4: GOOGLE_CREDENTIALS
- Name: `GOOGLE_CREDENTIALS`
- Value: (from `prepare-secrets.sh` output)
- Click "Add secret"

#### Secret 5: GOOGLE_TOKEN
- Name: `GOOGLE_TOKEN`
- Value: (from `prepare-secrets.sh` output)
- Click "Add secret"

**Verify:** You should now see 5 secrets listed.

---

### STEP 5: Test the Workflow (5 minutes)

1. Go to **Actions** tab in your repository
2. Click **"Daily CPO Output"** workflow on the left
3. Click **"Run workflow"** dropdown (top right)
4. Click green **"Run workflow"** button
5. Wait ~2-3 minutes
6. Check your email!

**Expected result:**
- ✅ Workflow shows green checkmark
- ✅ Email arrives at apurva.garware@gmail.com
- ✅ All steps completed successfully

**If something fails:**
- Click on the red X to see error
- Check the troubleshooting section in README.md
- Most common issue: Wrong API key or expired Google token

---

### STEP 6: Verify Schedule (1 minute)

The workflow is already set to run at 9:00 AM PST daily.

**To confirm:**
1. Open `.github/workflows/daily-brief.yml` in your repository
2. Look for:
   ```yaml
   schedule:
     - cron: '0 17 * * *'  # 9 AM PST = 5 PM UTC
   ```

**First automatic run:** Tomorrow at 9:00 AM PST

---

## ✅ You're Done!

### What Happens Next

**Tomorrow at 9 AM PST:**
- GitHub Actions runs automatically
- Fetches your Google Calendar/Gmail
- Generates brief with Claude
- Sends email
- If it fails → sends failure alert

**You can:**
- ✅ Turn off laptop - it's not needed anymore
- ✅ View run history in GitHub Actions tab
- ✅ Download any brief from Artifacts
- ✅ Manually trigger anytime from Actions tab
- ✅ Get failure notifications immediately

---

## 📅 Important: Set Reminder

**Google OAuth tokens expire every 7 days.**

Set a calendar reminder:
- **What:** "Refresh Daily Brief Google Token"
- **When:** Every 7 days
- **How:**
  ```bash
  cd ~/cpo-output/github-migration
  ./refresh-google-token.sh
  ```
  Then update the `GOOGLE_TOKEN` secret in GitHub.

---

## 🎯 Success Checklist

After setup, verify:

- [x] Repository created (private)
- [x] All files pushed to GitHub
- [x] 5 secrets configured
- [x] Manual test run successful
- [x] Email received
- [x] Schedule confirmed (9 AM PST)
- [ ] Calendar reminder set for token refresh
- [ ] Laptop cron disabled (optional, after 1 week of success)

---

## 🆘 Something Wrong?

### Common Issues

**"Invalid API key"**
→ Check CLAUDE_API_KEY is correct, starts with `sk-ant-`

**"Google credentials not valid"**
→ Run `./refresh-google-token.sh` and update secret

**"Email sending failed"**
→ Check RESEND_API_KEY is correct

**"Workflow not found"**
→ Make sure you pushed all files, especially `.github/workflows/daily-brief.yml`

**Can't find Actions tab**
→ Go to Settings → Actions → General → Enable Actions

---

## 📊 Monitor Your Success

**Daily:**
1. Check if email arrived at 9 AM
2. If not, go to GitHub Actions tab to see what failed

**Weekly:**
1. Review success rate in Actions tab
2. Check for any pattern in failures

**Every 7 days:**
1. Refresh Google OAuth token
2. Update GOOGLE_TOKEN secret

---

## 🚀 Optional: Disable Laptop Cron

After 1 week of successful GitHub Actions runs:

```bash
# List current cron jobs
crontab -l

# Edit crontab
crontab -e

# Comment out or delete the daily brief lines
# Save and exit
```

Keep the files as backup, but you don't need the laptop running anymore!

---

## Next Steps

1. ✅ Complete this setup guide
2. ✅ Wait for tomorrow's 9 AM run
3. ✅ Monitor for first week
4. ✅ Set up token refresh reminder
5. ✅ Enjoy 99%+ reliability!

**Questions?** See the full README.md for detailed documentation.
