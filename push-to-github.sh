#!/bin/bash
#
# Push Daily CPO Output to GitHub
# Username: ag-ait
#

set -e

cd ~/cpo-output/github-migration

echo "📦 Initializing git repository..."
git init

echo "📝 Adding all files..."
git add .

echo "💾 Creating commit..."
git commit -m "Initial commit: Daily CPO Output automation"

echo "🌿 Setting main branch..."
git branch -M main

echo "🔗 Connecting to GitHub..."
git remote add origin https://github.com/ag-ait/daily-cpo-output.git

echo "🚀 Pushing to GitHub..."
git push -u origin main

echo ""
echo "✅ Successfully pushed to GitHub!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Go to: https://github.com/ag-ait/daily-cpo-output"
echo ""
echo "2. Go to Settings → Secrets and variables → Actions"
echo ""
echo "3. Add 5 secrets (see terminal output above for values):"
echo "   - RESEND_API_KEY"
echo "   - NEWS_API_KEY"
echo "   - CLAUDE_API_KEY (from Anthropic Console)"
echo "   - GOOGLE_CREDENTIALS"
echo "   - GOOGLE_TOKEN"
echo ""
echo "4. Go to Actions tab → Daily CPO Output → Run workflow"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
