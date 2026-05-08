#!/usr/bin/env python3
"""
Send email via Resend API
"""

import os
import sys
import json
import argparse
import requests
from datetime import datetime

def markdown_to_html(markdown_text):
    """Simple markdown to HTML conversion"""
    html = markdown_text

    # Headers
    html = html.replace('\n## ', '\n<h2>').replace('\n###', '\n<h3>')
    lines = html.split('\n')
    result = []
    for line in lines:
        if line.startswith('<h2>'):
            result.append(line.replace('<h2>', '<h2>') + '</h2>')
        elif line.startswith('<h3>'):
            result.append(line.replace('<h3>', '<h3>') + '</h3>')
        else:
            result.append(line)
    html = '\n'.join(result)

    # Bold
    import re
    html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html)

    # Line breaks
    html = html.replace('\n\n', '</p><p>')
    html = '<p>' + html + '</p>'

    # Clean up
    html = html.replace('<p></p>', '')
    html = html.replace('<p><h2>', '<h2>').replace('</h2></p>', '</h2>')
    html = html.replace('<p><h3>', '<h3>').replace('</h3></p>', '</h3>')

    return html

def send_email(to, subject, content):
    """Send email via Resend API"""
    api_key = os.environ.get('RESEND_API_KEY')
    if not api_key:
        print("ERROR: RESEND_API_KEY not set", file=sys.stderr)
        return False

    # Convert markdown to HTML
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
            }}
            h2 {{
                color: #667eea;
                border-bottom: 2px solid #667eea;
                padding-bottom: 10px;
                margin-top: 30px;
            }}
            h3 {{
                color: #764ba2;
                margin-top: 20px;
            }}
            p {{
                margin: 10px 0;
            }}
            pre {{
                background: #f5f5f5;
                padding: 15px;
                border-radius: 5px;
                overflow-x: auto;
            }}
        </style>
    </head>
    <body>
        {markdown_to_html(content)}
    </body>
    </html>
    """

    # Send via Resend API
    url = "https://api.resend.com/emails"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    data = {
        "from": "Daily CPO Output <onboarding@resend.dev>",
        "to": [to],
        "subject": subject,
        "html": html_content
    }

    try:
        response = requests.post(url, headers=headers, json=data, timeout=30)
        response.raise_for_status()

        result = response.json()
        print(f"✅ Email sent successfully")
        print(f"Email ID: {result.get('id', 'unknown')}")
        return True

    except requests.exceptions.RequestException as e:
        print(f"❌ Email sending failed: {e}", file=sys.stderr)
        if hasattr(e, 'response') and e.response:
            print(f"Response: {e.response.text}", file=sys.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(description='Send email via Resend API')
    parser.add_argument('--to', required=True, help='Recipient email address')
    parser.add_argument('--subject', required=True, help='Email subject')
    parser.add_argument('--content', required=True, help='Email content (markdown)')

    args = parser.parse_args()

    success = send_email(args.to, args.subject, args.content)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
