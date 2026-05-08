#!/bin/bash
#
# Refresh Google OAuth token for GitHub Actions
# Run this every 7 days and update GOOGLE_TOKEN secret
#

set -e

echo "🔄 Refreshing Google OAuth Token..."
echo ""

# Run the fetch script to refresh token
python3 fetch-google-data.py > /dev/null 2>&1

if [ ! -f ~/.google/token.pickle ]; then
    echo "❌ ERROR: Token refresh failed"
    exit 1
fi

echo "✅ Token refreshed successfully"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Copy this value and update GOOGLE_TOKEN secret in GitHub:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat ~/.google/token.pickle | base64
echo ""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Steps to update:"
echo "1. Go to: https://github.com/YOUR_USERNAME/daily-cpo-output/settings/secrets/actions"
echo "2. Click on GOOGLE_TOKEN"
echo "3. Click 'Update secret'"
echo "4. Paste the value above"
echo "5. Click 'Update secret'"
echo ""
echo "Set a reminder to do this again in 7 days!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
