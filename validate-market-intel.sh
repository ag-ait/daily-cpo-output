#!/bin/bash
#
# Market Intel Validation Script
# Checks for hallucinations and quality issues in market intelligence brief
#

set -euo pipefail

BRIEF_FILE="$1"
NEWS_DATA_FILE="$2"
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

if [ ! -f "$NEWS_DATA_FILE" ]; then
    echo "ERROR: News data file not found: $NEWS_DATA_FILE"
    exit 1
fi

log "Starting Market Intel validation..."
log "Brief: $BRIEF_FILE"
log "Source data: $NEWS_DATA_FILE"

# Extract content
BRIEF_CONTENT=$(cat "$BRIEF_FILE")
NEWS_DATA=$(cat "$NEWS_DATA_FILE")

# Validation 1: Check required sections
log ""
log "CHECK 1: Required sections present"
REQUIRED_SECTIONS=(
    "🔍 COMPETITOR WATCH"
    "🚀 AI & SAAS UPDATES"
    "⚡ SO WHAT"
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

# Validation 2: Verify URLs are valid and accessible
log ""
log "CHECK 2: URL validation"

# Extract all URLs from the brief
URLS=$(grep -oE 'https?://[^ ]+' "$BRIEF_FILE" | sed 's/)$//' | sed 's/,$//' || true)

if [ -n "$URLS" ]; then
    TOTAL_URLS=$(echo "$URLS" | wc -l | tr -d ' ')
    VALID_URLS=0
    INVALID_URLS=()

    while IFS= read -r url; do
        if [ -n "$url" ]; then
            # Check if URL exists in source data
            if echo "$NEWS_DATA" | grep -qF "$url" 2>/dev/null; then
                VALID_URLS=$((VALID_URLS + 1))
                log "  ✅ URL in source: ${url:0:60}..."
            else
                # URL might be valid but not in our source (could be hallucinated)
                # Do a basic format check
                if [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$ ]]; then
                    log "  ⚠️  URL not in source: ${url:0:60}..."
                    # Don't fail, but log it
                else
                    INVALID_URLS+=("$url")
                    VALIDATION_PASSED=false
                    log "  ❌ Invalid URL format: ${url:0:60}..."
                fi
            fi
        fi
    done <<< "$URLS"

    if [ ${#INVALID_URLS[@]} -gt 0 ]; then
        ISSUES+=("${#INVALID_URLS[@]} URLs with invalid format detected")
    fi

    SOURCE_MATCH_PERCENT=$((VALID_URLS * 100 / TOTAL_URLS))
    log "  📊 URLs from source data: $SOURCE_MATCH_PERCENT%"

    if [ "$SOURCE_MATCH_PERCENT" -lt 50 ]; then
        ISSUES+=("Only $SOURCE_MATCH_PERCENT% of URLs match source data (possible hallucination)")
        VALIDATION_PASSED=false
        log "  ❌ Low source match rate"
    fi
else
    # No URLs found - this is suspicious for a news brief
    if ! grep -qi "no news\|no updates\|no articles" "$BRIEF_FILE"; then
        ISSUES+=("No URLs found in market intel brief")
        VALIDATION_PASSED=false
        log "  ❌ No URLs found"
    fi
fi

# Validation 3: Check competitor mentions match available data
log ""
log "CHECK 3: Competitor coverage validation"

COMPETITORS=("OpenAI" "Anthropic" "Scale AI" "Glean")

for competitor in "${COMPETITORS[@]}"; do
    # Check if we have news data for this competitor
    HAS_NEWS=$(echo "$NEWS_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    competitors = data.get('competitors', {})
    articles = competitors.get('$competitor', {}).get('articles', [])
    print(len(articles))
except:
    print('0')
" 2>/dev/null || echo "0")

    # Check if competitor appears in brief
    MENTIONED_IN_BRIEF=$(grep -c "$competitor" "$BRIEF_FILE" 2>/dev/null || echo "0")
    MENTIONED_IN_BRIEF=$(echo "$MENTIONED_IN_BRIEF" | tr -d '\n' | head -1)

    if [ "$HAS_NEWS" -gt 0 ] && [ "$MENTIONED_IN_BRIEF" -eq 0 ]; then
        log "  ⚠️  $competitor: Has $HAS_NEWS articles but not in brief"
        # This is OK - brief should filter for relevance
    elif [ "$HAS_NEWS" -eq 0 ] && [ "$MENTIONED_IN_BRIEF" -gt 0 ]; then
        ISSUES+=("$competitor mentioned in brief but no source data available")
        VALIDATION_PASSED=false
        log "  ❌ $competitor: In brief but no source data"
    else
        log "  ✅ $competitor: Coverage appropriate (source=$HAS_NEWS, brief=$MENTIONED_IN_BRIEF)"
    fi
done

# Validation 4: Check for hallucinated company names
log ""
log "CHECK 4: Hallucination detection - company names"

# Extract company names mentioned in the brief (look for **CompanyName** pattern)
MENTIONED_COMPANIES=$(grep -oE '\*\*[A-Z][a-zA-Z0-9 ]+\*\*' "$BRIEF_FILE" | sed 's/\*\*//g' || true)

# Known valid companies (can expand this list)
KNOWN_COMPANIES=(
    "OpenAI"
    "Anthropic"
    "Scale AI"
    "Glean"
    "Microsoft"
    "Google"
    "Amazon"
    "Meta"
    "Apple"
    "NVIDIA"
    "AMD"
    "Intel"
    "Tesla"
    "SpaceX"
    "Stripe"
    "Databricks"
    "Snowflake"
    "Salesforce"
    "Oracle"
    "IBM"
    "SAP"
    "Adobe"
    "Cisco"
    "Dell"
    "HP"
    "Samsung"
    "DeepSeek"
    "Sierra"
    "Fortinet"
    "Asana"
    "Robinhood"
)

while IFS= read -r company; do
    if [ -n "$company" ]; then
        # Check if it's a known company OR appears in source data
        IS_KNOWN=false
        for known in "${KNOWN_COMPANIES[@]}"; do
            if [ "$company" = "$known" ]; then
                IS_KNOWN=true
                break
            fi
        done

        if [ "$IS_KNOWN" = true ]; then
            log "  ✅ Known company: $company"
        else
            # Check if in source data
            if echo "$NEWS_DATA" | grep -qiF "$company" 2>/dev/null; then
                log "  ✅ Company in source: $company"
            else
                log "  ⚠️  Unknown company (not in source): $company"
                # Don't fail - might be legitimate new company
            fi
        fi
    fi
done <<< "$MENTIONED_COMPANIES"

# Validation 5: Check for obviously fake news patterns
log ""
log "CHECK 5: Fake news detection"

SUSPICIOUS_PATTERNS=(
    "raises \$[0-9,]+ (billion|trillion)"
    "valuation of \$[0-9,]+ (trillion|quadrillion)"
    "CEO.*fired"
    "CEO.*arrested"
    "files for bankruptcy"
    "acquires.*for \$[0-9,]+ trillion"
)

SUSPICIOUS_FOUND=false
for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
    if grep -qiE "$pattern" "$BRIEF_FILE"; then
        # Check if this appears in source data too
        if ! echo "$NEWS_DATA" | grep -qiE "$pattern"; then
            ISSUES+=("Suspicious claim not in source: $pattern")
            VALIDATION_PASSED=false
            SUSPICIOUS_FOUND=true
            log "  ⚠️  Suspicious pattern: $pattern"
        fi
    fi
done

if [ "$SUSPICIOUS_FOUND" = false ]; then
    log "  ✅ No obviously suspicious claims"
fi

# Validation 6: Date validation
log ""
log "CHECK 6: Date consistency"

# Market intel should be recent (within last 2 days)
BRIEF_DATE=$(grep -oE '[A-Z][a-z]+, [A-Z][a-z]+ [0-9]{1,2}, [0-9]{4}' "$BRIEF_FILE" | head -1 || echo "")

if [ -n "$BRIEF_DATE" ]; then
    # Parse the date and check it's within 2 days of today
    BRIEF_EPOCH=$(date -j -f "%A, %B %d, %Y" "$BRIEF_DATE" "+%s" 2>/dev/null || echo "0")
    TODAY_EPOCH=$(date "+%s")
    DAYS_DIFF=$(( (TODAY_EPOCH - BRIEF_EPOCH) / 86400 ))

    if [ "$DAYS_DIFF" -gt 2 ] || [ "$DAYS_DIFF" -lt -1 ]; then
        ISSUES+=("Market intel date is $DAYS_DIFF days off from today")
        VALIDATION_PASSED=false
        log "  ⚠️  Date off by $DAYS_DIFF days: $BRIEF_DATE"
    else
        log "  ✅ Date reasonable: $BRIEF_DATE"
    fi
else
    log "  ⚠️  Could not extract date from brief"
fi

# Validation 7: Check brief is not empty or too short
log ""
log "CHECK 7: Content length validation"

LINE_COUNT=$(wc -l < "$BRIEF_FILE")
if [ "$LINE_COUNT" -lt 20 ]; then
    ISSUES+=("Market intel brief too short: $LINE_COUNT lines (expected >20)")
    VALIDATION_PASSED=false
    log "  ❌ Brief too short: $LINE_COUNT lines"
else
    log "  ✅ Length acceptable: $LINE_COUNT lines"
fi

# Validation 8: Check for generic placeholder content
log ""
log "CHECK 8: Placeholder detection"

PLACEHOLDER_PATTERNS=(
    "\\[placeholder\\]"
    "\\[TBD\\]"
    "EXAMPLE"
    "TODO"
    "FIXME"
    "Sample news"
    "Example company"
)

for pattern in "${PLACEHOLDER_PATTERNS[@]}"; do
    if grep -qi "$pattern" "$BRIEF_FILE"; then
        ISSUES+=("Placeholder content detected: $pattern")
        VALIDATION_PASSED=false
        log "  ❌ Found placeholder: $pattern"
    fi
done

log "  ✅ No placeholder content detected"

# Validation 9: Verify "SO WHAT" section has actionable insights
log ""
log "CHECK 9: Actionable insights validation"

SO_WHAT_SECTION=$(sed -n '/⚡ SO WHAT/,/━━━/p' "$BRIEF_FILE")
SO_WHAT_BULLETS=$(echo "$SO_WHAT_SECTION" | grep "^•" | wc -l | tr -d ' ')

if [ "$SO_WHAT_BULLETS" -lt 2 ]; then
    ISSUES+=("SO WHAT section has too few insights ($SO_WHAT_BULLETS, expected >=2)")
    VALIDATION_PASSED=false
    log "  ❌ Too few insights: $SO_WHAT_BULLETS"
else
    log "  ✅ Sufficient insights: $SO_WHAT_BULLETS bullets"
fi

# Summary
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "VALIDATION SUMMARY"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$VALIDATION_PASSED" = true ]; then
    log "✅ Market Intel PASSED all validations"
    exit 0
else
    log "❌ Market Intel FAILED validation"
    log ""
    log "Issues found:"
    for issue in "${ISSUES[@]}"; do
        log "  - $issue"
    done
    exit 1
fi
