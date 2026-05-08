#!/bin/bash
#
# Prepare secrets for GitHub Actions
# Run this script and copy the output to GitHub Secrets
#

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  GitHub Actions Secrets - Ready to Copy-Paste             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if files exist
if [ ! -f ~/.env ]; then
    echo "❌ ERROR: ~/.env not found"
    echo "   Please make sure your .env file exists with RESEND_API_KEY and NEWS_API_KEY"
    exit 1
fi

if [ ! -f ~/.google/credentials.json ]; then
    echo "❌ ERROR: ~/.google/credentials.json not found"
    echo "   Please set up Google OAuth first"
    exit 1
fi

if [ ! -f ~/.google/token.pickle ]; then
    echo "⚠️  WARNING: ~/.google/token.pickle not found"
    echo "   Running fetch-google-data.py to generate token..."
    python3 ~/cpo-output/fetch-google-data.py > /dev/null 2>&1 || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECRET 1: RESEND_API_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
source ~/.env
echo "$RESEND_API_KEY"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECRET 2: NEWS_API_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$NEWS_API_KEY"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECRET 3: CLAUDE_API_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  You need to get this from Anthropic Console:"
echo "    https://console.anthropic.com/settings/keys"
echo ""
echo "    Create a new key and paste it here when adding secrets."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECRET 4: GOOGLE_CREDENTIALS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat ~/.google/credentials.json
echo ""
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECRET 5: GOOGLE_TOKEN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f ~/.google/token.pickle ]; then
    cat ~/.google/token.pickle | base64
else
    echo "❌ ERROR: token.pickle not found"
    echo "   Run: python3 ~/cpo-output/fetch-google-data.py"
    echo "   Then run this script again"
fi
echo ""
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Next Steps:                                               ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  1. Copy each secret value above                           ║"
echo "║  2. Go to GitHub repo → Settings → Secrets → Actions       ║"
echo "║  3. Click 'New repository secret'                          ║"
echo "║  4. Add each secret with exact name and value              ║"
echo "║  5. Run test workflow from Actions tab                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
