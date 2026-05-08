# Daily CPO Output - GitHub Actions Migration

Automated daily brief delivery powered by GitHub Actions for 99%+ reliability.

---

## 🚀 Quick Start

Follow these steps to migrate from laptop-based to cloud-based execution.

### Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `daily-cpo-output` (or whatever you prefer)
3. **Important:** Set to **Private** (keep your data secure)
4. Click "Create repository"

### Step 2: Upload Files

From your terminal:

```bash
cd ~/cpo-output/github-migration

# Initialize git
git init
git add .
git commit -m "Initial commit: Daily CPO Output automation"

# Connect to GitHub (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/daily-cpo-output.git
git branch -M main
git push -u origin main
```

Or use GitHub's web interface:
1. Click "uploading an existing file"
2. Drag and drop all files from `~/cpo-output/github-migration`
3. Commit changes

### Step 3: Configure Secrets

Go to your repository → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

#### 1. RESEND_API_KEY
```bash
# Get your current key
cat ~/.env | grep RESEND_API_KEY
```
Copy the value and add as secret.

#### 2. NEWS_API_KEY
```bash
# Get your current key
cat ~/.env | grep NEWS_API_KEY
```
Copy the value and add as secret.

#### 3. CLAUDE_API_KEY

You need an Anthropic API key. Get it from: https://console.anthropic.com/

1. Go to https://console.anthropic.com/settings/keys
2. Create new API key
3. Copy the key
4. Add as secret in GitHub

**Important:** This is different from the Claude CLI - this is the direct API.

#### 4. GOOGLE_CREDENTIALS

```bash
cat ~/.google/credentials.json
```
Copy the ENTIRE JSON output and add as secret.

#### 5. GOOGLE_TOKEN

```bash
# First, make sure your token is fresh
python3 ~/cpo-output/fetch-google-data.py

# Then encode it for GitHub
cat ~/.google/token.pickle | base64
```
Copy the base64 output and add as secret.

---

## Step 4: Test the Workflow

1. Go to your repository
2. Click "Actions" tab
3. Click "Daily CPO Output" workflow
4. Click "Run workflow" → "Run workflow" (green button)
5. Watch it execute (should take ~2 minutes)

**What to check:**
- ✅ All steps should be green
- ✅ You should receive an email
- ✅ Click on the run to see detailed logs
- ✅ Download artifacts to see generated briefs

**If it fails:**
- Click on the failed step to see error
- Common issues:
  - Google token expired → Re-run Step 3.5
  - API key wrong → Check secrets
  - Missing dependency → Check workflow file

---

## Step 5: Verify Schedule

The workflow is set to run automatically at 9:00 AM PST every day.

**To verify:**
1. Go to Actions tab
2. Click "Daily CPO Output"
3. Look for "This workflow has a workflow_dispatch event trigger"
4. The schedule is: `cron: '0 17 * * *'` (9 AM PST = 5 PM UTC)

**First scheduled run:** Tomorrow at 9 AM PST

---

## 📊 Monitoring

### View Run History

1. Go to repository → Actions tab
2. See all runs (green = success, red = failure)
3. Click any run to see details

### Check Logs

1. Click on a workflow run
2. Click on "generate-and-send-brief" job
3. Expand any step to see full output
4. Logs are kept for 90 days

### Download Briefs

Every run creates an artifact with:
- Final brief
- Individual sections
- Raw data files

To download:
1. Go to workflow run
2. Scroll to bottom
3. Click "daily-brief-XXX" under Artifacts
4. Downloads as ZIP

---

## 🔧 Maintenance

### Updating the Workflow

1. Edit `.github/workflows/daily-brief.yml` in repository
2. Commit changes
3. Next run will use updated workflow

### Refreshing Google OAuth Token

Google tokens expire every ~7 days. When you get failures:

```bash
# On your laptop
python3 ~/cpo-output/fetch-google-data.py

# Encode new token
cat ~/.google/token.pickle | base64

# Update secret in GitHub:
# Settings → Secrets → GOOGLE_TOKEN → Update
```

**Pro tip:** Set a calendar reminder every 7 days to refresh the token.

### Changing Schedule

Edit `.github/workflows/daily-brief.yml`:

```yaml
schedule:
  - cron: '0 17 * * *'  # Current: 9 AM PST
```

Cron format: `minute hour day month weekday`
Time is in UTC (PST + 8 hours)

Examples:
- 8 AM PST: `0 16 * * *`
- 10 AM PST: `0 18 * * *`
- Twice daily (9 AM & 5 PM PST):
  ```yaml
  - cron: '0 17 * * *'
  - cron: '0 1 * * *'
  ```

---

## 🚨 Troubleshooting

### Email Not Received

**Check:**
1. Go to Actions → Latest run → Check if green
2. If red, click to see error
3. Check spam folder
4. Verify RESEND_API_KEY is correct

**Fix:**
- Re-run workflow manually
- Check Resend dashboard for delivery status

### Google API Failure

**Error:** "Google credentials not valid"

**Fix:**
```bash
# Refresh token
python3 ~/cpo-output/fetch-google-data.py

# Update secret
cat ~/.google/token.pickle | base64
# Copy to GitHub Settings → Secrets → GOOGLE_TOKEN
```

### Claude API Failure

**Error:** "Authentication error" or "Rate limit"

**Fix:**
- Verify CLAUDE_API_KEY in secrets
- Check API quota at https://console.anthropic.com/
- Make sure you have credits/billing set up

### Workflow Not Running

**Check:**
1. Is the repository active? (GitHub disables workflows after 60 days of no commits)
2. Is the schedule correct? (Remember UTC vs PST)
3. Are Actions enabled? (Settings → Actions → General → Allow all actions)

---

## 📈 Metrics & Dashboard

### GitHub Insights

Built-in metrics:
- Go to repository → Insights → Actions
- See run frequency, duration, success rate

### Custom Dashboard (Optional)

You can still use your local dashboard:
1. Export metrics from GitHub Actions
2. Import to local metrics.json
3. View at http://localhost:8080/dashboard.html

Or build a web-based dashboard that pulls from GitHub API.

---

## 🔐 Security

### Best Practices

✅ **Do:**
- Keep repository private
- Use GitHub Secrets for all API keys
- Rotate tokens regularly
- Review Actions logs for sensitive data

❌ **Don't:**
- Make repository public (contains business data)
- Commit API keys to code
- Share workflow run links publicly
- Log sensitive information

### What's Encrypted

- All secrets (never visible in logs)
- Repository contents (private repo)
- Artifacts after download

### What's Visible

- Workflow runs (to anyone with repo access)
- Log output (to anyone with repo access)
- Timing and success/failure status

---

## 💡 Advanced Features

### Manual Triggers with Custom Date

Edit workflow to add inputs:

```yaml
workflow_dispatch:
  inputs:
    date:
      description: 'Date for the brief (YYYY-MM-DD)'
      required: false
      default: 'today'
```

### Send to Multiple Recipients

Edit `send-email.py` or add more email steps.

### Slack Notifications

Add Slack webhook to workflow:

```yaml
- name: Notify Slack
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -d '{"text":"Daily brief sent successfully!"}'
```

### Save Briefs to Google Drive

Add step to upload artifacts to Google Drive API.

---

## 🆘 Getting Help

### Common Issues

| Issue | Solution |
|-------|----------|
| Token expired | Refresh Google OAuth token |
| API rate limit | Check Anthropic console, upgrade plan |
| Workflow disabled | Make a commit to re-enable |
| Email bounced | Check Resend dashboard |
| Missing data | Check individual step logs |

### Support Resources

- GitHub Actions docs: https://docs.github.com/actions
- Anthropic API docs: https://docs.anthropic.com/
- Resend API docs: https://resend.com/docs
- Google API docs: https://developers.google.com/calendar

---

## 🔄 Rollback Plan

If something goes wrong, you can always:

1. **Keep laptop as backup:**
   - Your current cron jobs still exist
   - Can re-enable anytime
   - Serves as failsafe

2. **Disable GitHub workflow:**
   - Settings → Actions → Disable Actions
   - Re-enable laptop cron

3. **Hybrid approach:**
   - Run both (they won't conflict due to lock files)
   - GitHub as primary, laptop as backup

---

## ✅ Success Checklist

After setup, verify:

- [ ] Repository created and private
- [ ] All files uploaded
- [ ] All 5 secrets configured
- [ ] Manual test run successful
- [ ] Email received
- [ ] Artifacts downloadable
- [ ] Schedule verified (9 AM PST)
- [ ] Failure notification works
- [ ] Calendar reminder set for token refresh

---

## 📊 Expected Results

### Reliability

- **Before (Laptop):** 68% success rate
- **After (GitHub Actions):** 99%+ expected

### Benefits

✅ No laptop dependency
✅ No network issues
✅ No OAuth environment problems
✅ Full execution history
✅ Instant failure notifications
✅ Manual trigger capability
✅ Free (GitHub Actions free tier)

---

## Next Steps

1. **Complete setup** (follow Steps 1-5 above)
2. **Monitor first week** (check daily to build confidence)
3. **Disable laptop cron** (after 1 week of success)
4. **Set up token refresh reminder**
5. **Enjoy reliable daily briefs!**

---

## Questions?

This README should cover everything, but if you hit issues:
1. Check the troubleshooting section
2. Review GitHub Actions logs
3. Test each component individually
4. Check API service status pages
