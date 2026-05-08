#!/usr/bin/env python3
"""
Fetch Google Calendar and Gmail data for CoS brief
Outputs JSON to stdout for orchestrator consumption
"""

import json
import os
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

# Google API imports
try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
    import pickle
except ImportError:
    print(json.dumps({"error": "Google API libraries not installed. Run: pip3 install google-auth-oauthlib google-auth-httplib2 google-api-python-client"}))
    sys.exit(1)

# Paths
CREDENTIALS_FILE = Path.home() / '.google' / 'credentials.json'
TOKEN_FILE = Path.home() / '.google' / 'token.pickle'

# VIP contacts to monitor
VIP_CONTACTS = ['Nikhyl Singhal', 'Joel Lowenstein', 'Kunal']

# Retry configuration
MAX_RETRIES = 3
RETRY_DELAY = 2  # Initial delay in seconds

def retry_with_backoff(func, max_retries=MAX_RETRIES):
    """Retry a function with exponential backoff"""
    for attempt in range(max_retries):
        try:
            result = func()
            return result
        except Exception as e:
            if attempt == max_retries - 1:
                # Last attempt failed, raise the error
                raise e
            else:
                # Wait with exponential backoff
                delay = RETRY_DELAY * (2 ** attempt)
                print(f"Attempt {attempt + 1} failed: {str(e)}. Retrying in {delay}s...", file=sys.stderr)
                time.sleep(delay)

def get_google_credentials():
    """Authenticate and return Google API credentials"""
    creds = None

    # Load existing token
    if TOKEN_FILE.exists():
        with open(TOKEN_FILE, 'rb') as token:
            creds = pickle.load(token)

    # Refresh if expired
    if creds and creds.expired and creds.refresh_token:
        def refresh_token():
            creds.refresh(Request())
            with open(TOKEN_FILE, 'wb') as token:
                pickle.dump(creds, token)
            return True

        retry_with_backoff(refresh_token)

    return creds

def fetch_calendar_events(creds):
    """Fetch today's calendar events with retry logic"""
    def _fetch():
        service = build('calendar', 'v3', credentials=creds)

        # Get today's date range
        now = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = now + timedelta(days=1)

        events_result = service.events().list(
            calendarId='primary',
            timeMin=now.isoformat() + 'Z',
            timeMax=end_of_day.isoformat() + 'Z',
            singleEvents=True,
            orderBy='startTime'
        ).execute()

        events = events_result.get('items', [])

        # Format events
        formatted_events = []
        for event in events:
            start = event['start'].get('dateTime', event['start'].get('date'))
            summary = event.get('summary', 'No title')

            # Parse time
            if 'T' in start:
                dt = datetime.fromisoformat(start.replace('Z', '+00:00'))
                time_str = dt.strftime('%I:%M %p').lstrip('0')
            else:
                time_str = 'All day'

            formatted_events.append({
                'time': time_str,
                'summary': summary
            })

        return formatted_events

    try:
        return retry_with_backoff(_fetch)
    except Exception as e:
        return {"error": str(e)}

def fetch_gmail_inbox(creds):
    """Fetch inbox status and VIP emails with retry logic"""
    def _fetch():
        service = build('gmail', 'v1', credentials=creds)

        # Get unread count
        unread = service.users().messages().list(
            userId='me',
            q='is:unread',
            maxResults=100
        ).execute()

        unread_count = len(unread.get('messages', []))

        # Check for VIP emails
        vip_emails = []
        for contact in VIP_CONTACTS:
            query = f'from:"{contact}" is:unread'
            results = service.users().messages().list(
                userId='me',
                q=query,
                maxResults=5
            ).execute()

            messages = results.get('messages', [])
            for msg in messages:
                msg_detail = service.users().messages().get(
                    userId='me',
                    id=msg['id'],
                    format='metadata',
                    metadataHeaders=['From', 'Subject']
                ).execute()

                headers = {h['name']: h['value'] for h in msg_detail['payload']['headers']}
                vip_emails.append({
                    'from': headers.get('From', contact),
                    'subject': headers.get('Subject', 'No subject')
                })

        return {
            'unread_count': unread_count,
            'vip_emails': vip_emails
        }

    try:
        return retry_with_backoff(_fetch)
    except Exception as e:
        return {"error": str(e)}

def main():
    """Main execution"""
    try:
        # Get credentials
        creds = get_google_credentials()

        if not creds or not creds.valid:
            print(json.dumps({"error": "Google credentials not valid. Please re-authenticate."}))
            sys.exit(1)

        # Fetch data
        calendar_events = fetch_calendar_events(creds)
        inbox_data = fetch_gmail_inbox(creds)

        # Output JSON
        output = {
            "calendar": calendar_events,
            "inbox": inbox_data,
            "date": datetime.now().strftime('%A, %B %d, %Y')
        }

        print(json.dumps(output, indent=2))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == '__main__':
    main()
