#!/bin/bash
#
# Daily COS Agent - Claude-Powered Orchestrator
# Uses Claude AI to generate intelligent daily briefs
#

set -euo pipefail

# Configuration
OUTPUT_DIR="$HOME/cos-agent/briefs"
LOG_DIR="$HOME/cos-agent/logs"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="$LOG_DIR/cos-agent.log"
FINAL_BRIEF="$OUTPUT_DIR/daily-cos-agent-$DATE.md"
TEMP_DIR=$(mktemp -d)
LOCK_FILE="/tmp/brief-sent-$DATE"
FAILURE_LOCK="/tmp/brief-failed-$DATE"

# Metrics tracking
START_TIME=$(date +%s)
START_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
METRICS_SCRIPT="$HOME/cos-agent/track-metrics.sh"
GOOGLE_API_STATUS="pending"
EMAIL_DELIVERY_STATUS="pending"
CURRENT_HOUR=$(date +%H)

# Email config
RECIPIENT="apurva.garware@gmail.com"
EMAIL_SUBJECT="Daily COS Agent - $(date '+%B %d, %Y')"

# Ensure directories exist
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# Load environment variables
if [ -f ~/.env ]; then
    source ~/.env
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}

# Metrics recording function
record_metrics() {
    local status="$1"
    local failure_reason="${2:-}"

    if [ ! -f "$METRICS_SCRIPT" ]; then
        return
    fi

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Determine which attempt this was
    local attempt="manual"
    if [ "$CURRENT_HOUR" = "09" ]; then
        attempt="9am"
    elif [ "$CURRENT_HOUR" = "10" ]; then
        attempt="10am"
    elif [ "$CURRENT_HOUR" = "11" ]; then
        attempt="11am"
    elif [ "$CURRENT_HOUR" = "12" ]; then
        attempt="12pm"
    fi

    # Record the metric
    "$METRICS_SCRIPT" "$DATE" "$status" "$START_TIMESTAMP" "$end_timestamp" \
        "$duration" "$attempt" "$failure_reason" "$GOOGLE_API_STATUS" \
        "$EMAIL_DELIVERY_STATUS" >> "$LOG_FILE" 2>&1 || true
}

# Failure handler
handle_failure() {
    local failure_reason="$1"
    local failure_stage="${2:-unknown}"

    # Send detailed failure notification
    FAILURE_NOTIFIER="$HOME/cos-agent/send-failure-notification.sh"
    if [ -f "$FAILURE_NOTIFIER" ]; then
        log "Sending failure notification email..."
        "$FAILURE_NOTIFIER" "$failure_stage" "$failure_reason" "$LOG_FILE" "$RECIPIENT" >> "$LOG_FILE" 2>&1 || true
    fi

    record_metrics "failure" "$failure_reason"
}

trap cleanup EXIT

# Check if already sent today
if [ -f "$LOCK_FILE" ]; then
    log "✅ Brief already sent today at $(cat "$LOCK_FILE")"
    exit 0
fi

# Start
log "========================================="
log "Daily COS Agent - Starting (AI-Powered)"
log "========================================="
log "Date: $DATE"
log "Time: $(date '+%I:%M %p %Z')"
log ""

# Validate environment
if [ -z "${RESEND_API_KEY:-}" ]; then
    log "❌ ERROR: RESEND_API_KEY not set"
    handle_failure "RESEND_API_KEY not set"
    exit 1
fi

if [ -z "${NEWS_API_KEY:-}" ]; then
    log "⚠️  WARNING: NEWS_API_KEY not set (market intel may be limited)"
fi

log "✅ Environment validated"
log ""

# Step 1: Fetch Google Calendar and Gmail data
log "Step 1: Fetching Google Calendar and Gmail data..."
log "=================================================="

GOOGLE_DATA="$TEMP_DIR/google-data.json"
GOOGLE_SCRIPT="$HOME/cos-agent/fetch-google-data.py"

# Initialize fallback data
GOOGLE_FALLBACK='{"calendar": [], "inbox": {"unread_count": 0, "vip_emails": []}, "date": "'"$(date '+%A, %B %d, %Y')"'", "error": "Google data unavailable"}'

if [ ! -f "$GOOGLE_SCRIPT" ]; then
    log "⚠️  Google data fetch script not found: $GOOGLE_SCRIPT"
    echo "$GOOGLE_FALLBACK" > "$GOOGLE_DATA"
    GOOGLE_API_STATUS="script_not_found"
else
    # Fetch Google data (non-fatal if it fails)
    if python3 "$GOOGLE_SCRIPT" > "$GOOGLE_DATA" 2>>"$LOG_FILE"; then
        if [ -s "$GOOGLE_DATA" ]; then
            log "✅ Google data fetched ($(wc -l < "$GOOGLE_DATA") lines)"
            GOOGLE_API_STATUS="success"
        else
            log "⚠️  Google data is empty, using fallback"
            echo "$GOOGLE_FALLBACK" > "$GOOGLE_DATA"
            GOOGLE_API_STATUS="empty_response"
        fi
    else
        log "⚠️  Google data fetch failed, using fallback (brief will continue)"
        echo "$GOOGLE_FALLBACK" > "$GOOGLE_DATA"
        GOOGLE_API_STATUS="failed"
    fi
fi

# Step 2: Generate CoS Brief using Claude
log ""
log "Step 2: Generating Chief of Staff brief with Claude AI..."
log "==========================================================="

COS_OUTPUT="$TEMP_DIR/cos-brief.md"
COS_SKILL="$HOME/.claude/skills/daily-cos-brief.md"

if [ ! -f "$COS_SKILL" ]; then
    log "❌ CoS skill file not found: $COS_SKILL"
    exit 1
fi

# Read the skill instructions and pass to Claude with fetched Google data
COS_PROMPT=$(cat "$COS_SKILL")
COS_PROMPT+=$'\n\nHere is the data fetched from Google Calendar and Gmail for today:\n\n'
COS_PROMPT+=$(cat "$GOOGLE_DATA")
COS_PROMPT+=$'\n\nAnalyze this data and generate the CoS brief in the specified format.'
COS_PROMPT+=$'\n\nOutput ONLY the markdown brief, no explanations or setup instructions.'

# Invoke Claude with the skill prompt
if echo "$COS_PROMPT" | /opt/homebrew/bin/claude > "$COS_OUTPUT" 2>>"$LOG_FILE"; then
    if [ -s "$COS_OUTPUT" ]; then
        log "✅ CoS brief generated ($(wc -l < "$COS_OUTPUT") lines)"

        # Validate the CoS brief
        log ""
        log "Validating CoS brief for hallucinations..."
        VALIDATOR="$HOME/cos-agent/validate-cos-brief.sh"
        if [ -f "$VALIDATOR" ]; then
            if "$VALIDATOR" "$COS_OUTPUT" "$GOOGLE_DATA" "$LOG_FILE"; then
                log "✅ CoS brief validation passed"
            else
                log "❌ CoS brief validation failed - possible hallucinations detected"
                log "   Check log for details: $LOG_FILE"
                handle_failure "CoS brief validation failed - hallucinations or data mismatch detected" "CoS Brief Generation"
                exit 1
            fi
        else
            log "⚠️  Validator not found, skipping validation: $VALIDATOR"
        fi
    else
        log "❌ CoS brief generated but is empty"
        handle_failure "CoS brief generated but empty"
        exit 1
    fi
else
    log "❌ CoS brief generation failed"
    handle_failure "CoS brief generation failed"
    exit 1
fi

# Step 3: Fetch NewsAPI data
log ""
log "Step 3: Fetching news data from NewsAPI..."
log "==========================================="

NEWS_DATA="$TEMP_DIR/news-data.json"

# Fetch news for each company and format it properly
log "Fetching news for: OpenAI, Anthropic, Scale AI, Glean, AI industry..."

# Create a temp script to properly format the news data
cat > "$TEMP_DIR/format-news.py" <<'PYTHON_SCRIPT'
import sys
import json

news_data = {"competitors": {}}

companies = [
    ("OpenAI", sys.argv[1] if len(sys.argv) > 1 else "{}"),
    ("Anthropic", sys.argv[2] if len(sys.argv) > 2 else "{}"),
    ("Scale AI", sys.argv[3] if len(sys.argv) > 3 else "{}"),
    ("Glean", sys.argv[4] if len(sys.argv) > 4 else "{}")
]

for company, raw_json in companies:
    try:
        data = json.loads(raw_json)
        articles = data.get('articles', [])
        # Keep only relevant fields to reduce token usage
        news_data["competitors"][company] = {
            "articles": [
                {
                    "title": a.get('title', ''),
                    "description": a.get('description', ''),
                    "url": a.get('url', ''),
                    "publishedAt": a.get('publishedAt', '')
                }
                for a in articles[:20]  # Limit to 20 most recent articles per company
            ]
        }
    except:
        news_data["competitors"][company] = {"articles": []}

print(json.dumps(news_data, indent=2))
PYTHON_SCRIPT

# Fetch news for each company
OPENAI_NEWS=$(curl -s "https://newsapi.org/v2/everything?q=OpenAI&from=$(date -u -v-1d '+%Y-%m-%d')&sortBy=publishedAt&language=en&apiKey=$NEWS_API_KEY" 2>/dev/null || echo '{}')
ANTHROPIC_NEWS=$(curl -s "https://newsapi.org/v2/everything?q=Anthropic&from=$(date -u -v-1d '+%Y-%m-%d')&sortBy=publishedAt&language=en&apiKey=$NEWS_API_KEY" 2>/dev/null || echo '{}')
SCALE_NEWS=$(curl -s "https://newsapi.org/v2/everything?q=\"Scale AI\"&from=$(date -u -v-1d '+%Y-%m-%d')&sortBy=publishedAt&language=en&apiKey=$NEWS_API_KEY" 2>/dev/null || echo '{}')
GLEAN_NEWS=$(curl -s "https://newsapi.org/v2/everything?q=Glean AI OR Glean search&from=$(date -u -v-1d '+%Y-%m-%d')&sortBy=publishedAt&language=en&apiKey=$NEWS_API_KEY" 2>/dev/null || echo '{}')

# Format the data using Python
python3 "$TEMP_DIR/format-news.py" "$OPENAI_NEWS" "$ANTHROPIC_NEWS" "$SCALE_NEWS" "$GLEAN_NEWS" > "$NEWS_DATA"

if [ ! -s "$NEWS_DATA" ]; then
    log "⚠️  NewsAPI data is empty, using fallback"
    echo '{"competitors": {}}' > "$NEWS_DATA"
fi

log "✅ News data fetched"

# Step 4: Generate Market Intel using Claude
log ""
log "Step 4: Generating Market Intelligence with Claude AI..."
log "========================================================="

MARKET_OUTPUT="$TEMP_DIR/market-intel.md"
MARKET_SKILL="$HOME/.claude/skills/daily-market-intel.md"

if [ ! -f "$MARKET_SKILL" ]; then
    log "❌ Market Intel skill file not found: $MARKET_SKILL"
    exit 1
fi

# Read the skill instructions and pass to Claude with fetched news data
MARKET_PROMPT=$(cat "$MARKET_SKILL")
MARKET_PROMPT+=$'\n\nHere is the news data fetched from NewsAPI for the last 24 hours:\n\n'
MARKET_PROMPT+=$(cat "$NEWS_DATA")
MARKET_PROMPT+=$'\n\nAnalyze this news data and generate the market intelligence brief in the specified format.'
MARKET_PROMPT+=$'\n\nOutput ONLY the markdown brief, no explanations or setup instructions.'

# Invoke Claude with the skill prompt
if echo "$MARKET_PROMPT" | /opt/homebrew/bin/claude > "$MARKET_OUTPUT" 2>>"$LOG_FILE"; then
    if [ -s "$MARKET_OUTPUT" ]; then
        log "✅ Market intel generated ($(wc -l < "$MARKET_OUTPUT") lines)"

        # Validate the Market Intel brief
        log ""
        log "Validating Market Intel for hallucinations..."
        VALIDATOR="$HOME/cos-agent/validate-market-intel.sh"
        if [ -f "$VALIDATOR" ]; then
            if "$VALIDATOR" "$MARKET_OUTPUT" "$NEWS_DATA" "$LOG_FILE"; then
                log "✅ Market Intel validation passed"
            else
                log "❌ Market Intel validation failed - possible hallucinations detected"
                log "   Check log for details: $LOG_FILE"
                handle_failure "Market Intel validation failed - hallucinated URLs or fabricated news stories detected" "Market Intel Generation"
                exit 1
            fi
        else
            log "⚠️  Validator not found, skipping validation: $VALIDATOR"
        fi
    else
        log "❌ Market intel generated but is empty"
        handle_failure "Market intel generated but empty"
        exit 1
    fi
else
    log "❌ Market intel generation failed"
    handle_failure "Market intel generation failed"
    exit 1
fi

# Step 5: Combine outputs
log ""
log "Step 5: Compiling final brief..."
log "================================="

# Build final brief
cat > "$FINAL_BRIEF" <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DAILY COS AGENT
$(date '+%A, %B %d, %Y')
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

# Add CoS brief
cat "$COS_OUTPUT" >> "$FINAL_BRIEF"
echo "" >> "$FINAL_BRIEF"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$FINAL_BRIEF"
echo "" >> "$FINAL_BRIEF"

# Add Market Intel
cat "$MARKET_OUTPUT" >> "$FINAL_BRIEF"
echo "" >> "$FINAL_BRIEF"

# Add footer
cat >> "$FINAL_BRIEF" <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Generated by Claude AI (Sonnet 4.5)
Automated Daily Briefing | $(date '+%I:%M %p %Z')
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

log "✅ Brief compiled: $FINAL_BRIEF"
log "   Total size: $(wc -l < "$FINAL_BRIEF") lines"

# Step 5.5: Final workflow-level validation
log ""
log "Step 5.5: Final workflow validation..."
log "======================================="

WORKFLOW_VALIDATOR="$HOME/cos-agent/validate-final-brief.sh"
if [ -f "$WORKFLOW_VALIDATOR" ]; then
    if "$WORKFLOW_VALIDATOR" "$FINAL_BRIEF" "$LOG_FILE"; then
        log "✅ Final brief passed workflow validation"
    else
        log "❌ Final brief failed workflow validation"
        log "   Check log for details: $LOG_FILE"
        handle_failure "Final brief failed workflow-level validation checks" "Workflow Validation"
        exit 1
    fi
else
    log "⚠️  Workflow validator not found, skipping: $WORKFLOW_VALIDATOR"
fi

# Step 6: Send email
log ""
log "Step 6: Sending email..."
log "========================"

# Function to send failure notification
send_failure_notification() {
    local error_msg="$1"
    local failure_brief="/tmp/failure-notification-$DATE.txt"

    cat > "$failure_brief" <<FAILURE_EOF
Daily COS Agent - FAILURE ALERT
Date: $(date '+%A, %B %d, %Y %I:%M %p %Z')

ERROR: $error_msg

The daily brief failed to generate. Please check the logs:
$LOG_FILE

Last 20 log lines:
$(tail -20 "$LOG_FILE")
FAILURE_EOF

    # Try to send failure notification
    if [ -f "$HOME/.claude/skills/chief-of-staff-orchestrator/send-email.sh" ]; then
        "$HOME/.claude/skills/chief-of-staff-orchestrator/send-email.sh" \
            "$failure_brief" \
            "$RECIPIENT" \
            "⚠️ Daily COS Agent FAILED - $(date '+%B %d, %Y')" \
            >> "$LOG_FILE" 2>&1 || true
    fi

    # Create failure lock to prevent retries
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $error_msg" > "$FAILURE_LOCK"
}

# Reuse existing email sender
SEND_EMAIL_SCRIPT="$HOME/.claude/skills/chief-of-staff-orchestrator/send-email.sh"

if [ -f "$SEND_EMAIL_SCRIPT" ]; then
    if "$SEND_EMAIL_SCRIPT" "$FINAL_BRIEF" "$RECIPIENT" "$EMAIL_SUBJECT" >> "$LOG_FILE" 2>&1; then
        log "✅ Email sent successfully"
        EMAIL_DELIVERY_STATUS="success"
        # Create lock file to mark as sent
        echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$LOCK_FILE"
    else
        log "❌ Email sending failed"
        log "Brief saved at: $FINAL_BRIEF"
        EMAIL_DELIVERY_STATUS="failed"
        send_failure_notification "Email sending failed"
        handle_failure "Email sending failed"
        exit 1
    fi
else
    log "⚠️  Email sender not found, skipping email"
    log "Brief saved at: $FINAL_BRIEF"
    EMAIL_DELIVERY_STATUS="no_sender"
    # Still mark as sent to avoid retries
    echo "$(date '+%Y-%m-%d %H:%M:%S') - No email sender" > "$LOCK_FILE"
fi

# Success
log ""
log "========================================="
log "Daily COS Agent - Completed Successfully"
log "========================================="
log "Brief location: $FINAL_BRIEF"
log "Email sent to: $RECIPIENT"
log "AI-powered generation complete"
log ""

# Cleanup old files (keep last 7 days)
log "Cleaning up old briefs..."
find "$OUTPUT_DIR/daily-cos-agent-"* -type f -mtime +7 -exec rm -f {} \; 2>/dev/null || true
log "✅ Cleanup completed"
log ""

# Record success metrics
record_metrics "success"

log "========================================="

exit 0
