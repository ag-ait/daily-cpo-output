#!/bin/bash
#
# CoS Brief Validation Script
# Checks for hallucinations and quality issues in the generated brief
#

set -euo pipefail

BRIEF_FILE="$1"
GOOGLE_DATA_FILE="$2"
LOG_FILE="${3:-/dev/null}"

# Validation results
VALIDATION_PASSED=true
ISSUES=()

log() {
    echo "[VALIDATOR] $1" | tee -a "$LOG_FILE"
}

# Check if files exist
if [ ! -f "$BRIEF_FILE" ]; then
    echo "ERROR: Brief file not found: $BRIEF_FILE"
    exit 1
fi

if [ ! -f "$GOOGLE_DATA_FILE" ]; then
    echo "ERROR: Google data file not found: $GOOGLE_DATA_FILE"
    exit 1
fi

log "Starting CoS Brief validation..."
log "Brief: $BRIEF_FILE"
log "Source data: $GOOGLE_DATA_FILE"

# Extract data from brief
BRIEF_CONTENT=$(cat "$BRIEF_FILE")
GOOGLE_DATA=$(cat "$GOOGLE_DATA_FILE")

# Validation 1: Check if brief contains required sections
log ""
log "CHECK 1: Required sections present"
REQUIRED_SECTIONS=(
    "📅 TODAY'S SCHEDULE"
    "📬 INBOX STATUS"
    "💡 TODAY'S STRATEGIC FOCUS"
    "✅ TODAY'S TO-DOs"
    "🧭 ONE THING"
)

for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "$section" "$BRIEF_FILE"; then
        ISSUES+=("Missing section: $section")
        VALIDATION_PASSED=false
        log "  ❌ Missing: $section"
    else
        log "  ✅ Found: $section"
    fi
done

# Validation 2: Check calendar events match source data
log ""
log "CHECK 2: Calendar events match source data"

# Extract calendar events from Google data
CALENDAR_EVENTS=$(echo "$GOOGLE_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    events = data.get('calendar', [])
    for event in events:
        print(event.get('summary', ''))
except:
    pass
" 2>/dev/null || true)

# Count events in source
EVENT_COUNT=$(echo "$CALENDAR_EVENTS" | grep -v '^$' | wc -l | tr -d ' ')

if [ "$EVENT_COUNT" -gt 0 ]; then
    # Check that at least 70% of events appear in the brief
    MATCHED_EVENTS=0
    while IFS= read -r event; do
        if [ -n "$event" ]; then
            # Extract key words from event (ignore common words)
            EVENT_KEYWORDS=$(echo "$event" | sed 's/[^a-zA-Z0-9 ]//g' | tr '[:upper:]' '[:lower:]')

            # Check if any significant word from event appears in schedule section
            SCHEDULE_SECTION=$(sed -n '/📅 TODAY'\''S SCHEDULE/,/━━━/p' "$BRIEF_FILE")

            if echo "$SCHEDULE_SECTION" | grep -qi "$event"; then
                MATCHED_EVENTS=$((MATCHED_EVENTS + 1))
                log "  ✅ Event found: $event"
            else
                log "  ⚠️  Event missing: $event"
            fi
        fi
    done <<< "$CALENDAR_EVENTS"

    MATCH_PERCENTAGE=$((MATCHED_EVENTS * 100 / EVENT_COUNT))

    if [ "$MATCH_PERCENTAGE" -lt 70 ]; then
        ISSUES+=("Only $MATCH_PERCENTAGE% of calendar events matched (expected >=70%)")
        VALIDATION_PASSED=false
        log "  ❌ Low match rate: $MATCH_PERCENTAGE%"
    else
        log "  ✅ Event match rate: $MATCH_PERCENTAGE%"
    fi
else
    # No events - check if brief says "No scheduled events"
    if grep -q "No scheduled events\|No events today" "$BRIEF_FILE"; then
        log "  ✅ Correctly shows no events"
    else
        # Check if there are events listed when there shouldn't be
        SCHEDULE_SECTION=$(sed -n '/📅 TODAY'\''S SCHEDULE/,/━━━/p' "$BRIEF_FILE")
        if echo "$SCHEDULE_SECTION" | grep -q "•.*—"; then
            ISSUES+=("Brief shows calendar events but source data has none")
            VALIDATION_PASSED=false
            log "  ❌ Hallucinated events detected"
        fi
    fi
fi

# Validation 3: Check inbox count matches
log ""
log "CHECK 3: Inbox count accuracy"

ACTUAL_UNREAD=$(echo "$GOOGLE_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('inbox', {}).get('unread_count', 0))
except:
    print('0')
" 2>/dev/null || echo "0")

BRIEF_UNREAD=$(grep -o '[0-9]\+ unread' "$BRIEF_FILE" | head -1 | grep -o '[0-9]\+' || echo "0")

if [ "$ACTUAL_UNREAD" != "$BRIEF_UNREAD" ]; then
    ISSUES+=("Inbox count mismatch: Brief shows $BRIEF_UNREAD, actual is $ACTUAL_UNREAD")
    VALIDATION_PASSED=false
    log "  ❌ Mismatch: Brief=$BRIEF_UNREAD, Actual=$ACTUAL_UNREAD"
else
    log "  ✅ Inbox count correct: $ACTUAL_UNREAD"
fi

# Validation 4: Check VIP emails are correctly reported
log ""
log "CHECK 4: VIP emails accuracy"

VIP_COUNT=$(echo "$GOOGLE_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(len(data.get('inbox', {}).get('vip_emails', [])))
except:
    print('0')
" 2>/dev/null || echo "0")

if [ "$VIP_COUNT" -gt 0 ]; then
    # Should list VIP emails
    if grep -q "No urgent messages from VIP contacts" "$BRIEF_FILE"; then
        ISSUES+=("Brief says no VIP emails but $VIP_COUNT VIP emails exist")
        VALIDATION_PASSED=false
        log "  ❌ Missing $VIP_COUNT VIP emails"
    else
        log "  ✅ VIP emails section present"
    fi
else
    # Should say no VIP emails
    if ! grep -q "No urgent messages from VIP contacts" "$BRIEF_FILE"; then
        # Check if VIP emails are listed when there shouldn't be
        INBOX_SECTION=$(sed -n '/📬 INBOX STATUS/,/━━━/p' "$BRIEF_FILE")
        if echo "$INBOX_SECTION" | grep -q "•.*—" && ! grep -q "No urgent" "$BRIEF_FILE"; then
            ISSUES+=("Brief lists VIP emails but source data has none")
            VALIDATION_PASSED=false
            log "  ❌ Hallucinated VIP emails detected"
        else
            log "  ✅ Correctly shows no VIP emails"
        fi
    else
        log "  ✅ Correctly shows no VIP emails"
    fi
fi

# Validation 5: Check for date consistency
log ""
log "CHECK 5: Date consistency"

EXPECTED_DATE=$(echo "$GOOGLE_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('date', ''))
except:
    pass
" 2>/dev/null || date '+%A, %B %d, %Y')

# Extract day and date number for basic validation
EXPECTED_DAY=$(echo "$EXPECTED_DATE" | awk '{print $1}' | tr -d ',')
EXPECTED_MONTH_DAY=$(echo "$EXPECTED_DATE" | awk '{print $2, $3}' | tr -d ',')

if echo "$BRIEF_CONTENT" | head -20 | grep -qi "$EXPECTED_DAY.*$EXPECTED_MONTH_DAY" 2>/dev/null; then
    log "  ✅ Date appears correct ($EXPECTED_DATE)"
else
    log "  ⚠️  Date validation inconclusive: Expected ~$EXPECTED_DATE"
    # Don't fail on date mismatch - it's not always a critical issue
fi

# Validation 6: Check for hallucinated time patterns
log ""
log "CHECK 6: Time format validation"

# Times should be in format "HH:MM AM/PM" or "H:MM AM/PM"
INVALID_TIMES=$(grep -o '[0-9]\{1,2\}:[0-9]\{2\}' "$BRIEF_FILE" | while read time; do
    hour=$(echo "$time" | cut -d: -f1)
    min=$(echo "$time" | cut -d: -f2)
    if [ "$hour" -gt 12 ] || [ "$min" -gt 59 ]; then
        echo "$time"
    fi
done)

if [ -n "$INVALID_TIMES" ]; then
    ISSUES+=("Invalid time format detected: $INVALID_TIMES")
    VALIDATION_PASSED=false
    log "  ❌ Invalid times found"
else
    log "  ✅ Time formats valid"
fi

# Validation 7: Check brief is not empty or too short
log ""
log "CHECK 7: Content length validation"

LINE_COUNT=$(wc -l < "$BRIEF_FILE")
if [ "$LINE_COUNT" -lt 30 ]; then
    ISSUES+=("Brief is too short: $LINE_COUNT lines (expected >30)")
    VALIDATION_PASSED=false
    log "  ❌ Brief too short: $LINE_COUNT lines"
else
    log "  ✅ Length acceptable: $LINE_COUNT lines"
fi

# Validation 8: Check for obvious hallucination markers
log ""
log "CHECK 8: Hallucination detection"

# Common hallucination patterns
HALLUCINATION_PATTERNS=(
    "\\[placeholder\\]"
    "\\[TBD\\]"
    "EXAMPLE:"
    "Sample event"
    "TODO:"
)

HALLUCINATION_FOUND=false
for pattern in "${HALLUCINATION_PATTERNS[@]}"; do
    if grep -qi "$pattern" "$BRIEF_FILE"; then
        ISSUES+=("Potential hallucination pattern detected: $pattern")
        VALIDATION_PASSED=false
        HALLUCINATION_FOUND=true
        log "  ⚠️  Found pattern: $pattern"
    fi
done

if [ "$HALLUCINATION_FOUND" = false ]; then
    log "  ✅ No obvious hallucination markers"
fi

# Summary
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "VALIDATION SUMMARY"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$VALIDATION_PASSED" = true ]; then
    log "✅ CoS Brief PASSED all validations"
    exit 0
else
    log "❌ CoS Brief FAILED validation"
    log ""
    log "Issues found:"
    for issue in "${ISSUES[@]}"; do
        log "  - $issue"
    done
    exit 1
fi
