---
name: daily-cos-brief
description: Generate daily Chief of Staff brief with calendar, inbox triage, and strategic focus for Apurva
---

# Daily Chief of Staff Brief

Generate a comprehensive daily brief for Apurva Garware with today's schedule, inbox status, and strategic priorities.

## Data Sources

Google Calendar and Gmail data will be provided to you in JSON format containing:
- Calendar events for today from primary calendar
- Gmail inbox status and unread count
- VIP emails (if any)

**VIP Contacts to monitor:**
- Nikhyl Singhal
- Joel Lowenstein
- Kunal

## Output Structure

Generate markdown in this exact format:

```markdown
CoS BRIEF — {DayName}, {Month} {Day}
Good morning, Apurva.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📅 TODAY'S SCHEDULE

{List calendar events with times, format: • HH:MM AM/PM — Event Title}
{If no events: "No scheduled events today"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📬 INBOX STATUS

💬 {X} unread messages
{If VIP emails: list them with • FromName — Subject}
{If no VIP emails: ✅ No urgent messages from VIP contacts}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 TODAY'S STRATEGIC FOCUS

Based on your current search:

1. INTERVIEW PREPARATION
   • Review company research and prep docs for any scheduled interviews
   • Prepare 2-3 thoughtful questions for each conversation
   • Have your key stories ready (Chegg Study P&L, product wins)

2. NETWORKING FOLLOW-UPS
   • Send thank-you notes from recent conversations
   • Schedule next steps with active opportunities
   • Nurture relationships with VIP contacts

3. MARKET INTELLIGENCE
   • Track news from target companies (see above)
   • Monitor competitive landscape
   • Note relevant trends for interview discussions

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ TODAY'S TO-DOs (RANKED)

{Generate 5-7 contextual to-dos based on:
- Calendar events (prep for interviews/meetings)
- VIP emails requiring response
- Day of week context
- General job search activities}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧭 ONE THING

{Choose based on day of week:
- Monday: Make today's interview conversations memorable — be specific about your impact.
- Tuesday: Follow up on yesterday's conversations while they're fresh.
- Wednesday: Mid-week momentum: send that intro request you've been thinking about.
- Thursday: Review your week's progress and adjust priorities for tomorrow.
- Friday: Wrap up the week strong: tie up loose ends and plan next week.
- Saturday: Reflect on the week and identify 1-2 key lessons from conversations.
- Sunday: Strategic planning: map out your approach for the week ahead.}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 This brief includes:
✅ Today's calendar schedule
✅ Inbox status and VIP emails
✅ Strategic focus areas
✅ Prioritized daily to-dos
✅ Contextual priorities based on day of week

Market intelligence included in separate section below.
```

## Important Instructions

1. **AUTOMATED MODE**: You are running in an automated context. Calendar and Gmail data has been pre-fetched for you.
2. **CRITICAL**: You MUST use ONLY the calendar events and inbox data from the provided JSON. DO NOT make up or invent any events.
3. Analyze the provided JSON data containing today's calendar events and inbox status
4. Use real event times, subjects, and inbox counts from the provided data
5. Extract events from the "calendar" array in the JSON
6. Use the exact inbox count from the "inbox.unread_count" field
7. Generate contextual to-dos based on what's actually on the calendar
8. Output the markdown content directly - not wrapped in code fences
9. Keep it concise but actionable
10. **VALIDATION**: Before outputting, verify every calendar event appears in the source JSON data

## Self-Evaluation Checklist

Before completing, verify:
- [ ] Every calendar event in your output exists in the provided JSON "calendar" array
- [ ] The inbox count matches the "inbox.unread_count" field exactly
- [ ] VIP emails match the "inbox.vip_emails" array
- [ ] You have not invented or fabricated any calendar events
- [ ] Event times match the source data
- [ ] You have not used your training data to add events
