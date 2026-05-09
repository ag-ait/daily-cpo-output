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
    """Improved markdown to HTML conversion with better formatting"""
    import re

    # Split into paragraphs (separated by double newlines)
    paragraphs = markdown_text.split('\n\n')
    html_parts = []

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue

        # Headers
        if para.startswith('## '):
            content = para[3:].strip()
            html_parts.append(f'<h2>{content}</h2>')
        elif para.startswith('### '):
            content = para[4:].strip()
            html_parts.append(f'<h3>{content}</h3>')
        # Bullet lists
        elif para.startswith('- ') or para.startswith('* '):
            items = para.split('\n')
            list_html = '<ul>'
            for item in items:
                if item.strip().startswith(('- ', '* ')):
                    content = item.strip()[2:]
                    # Process bold within list items
                    content = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', content)
                    # Process links within list items
                    content = re.sub(r'\[(.+?)\]\((.+?)\)', r'<a href="\2">\1</a>', content)
                    list_html += f'<li>{content}</li>'
            list_html += '</ul>'
            html_parts.append(list_html)
        # Regular paragraphs
        else:
            # Replace single newlines with spaces (they're within a paragraph)
            para = para.replace('\n', ' ')
            # Process bold
            para = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', para)
            # Process links
            para = re.sub(r'\[(.+?)\]\((.+?)\)', r'<a href="\2">\1</a>', para)
            html_parts.append(f'<p>{para}</p>')

    return '\n'.join(html_parts)

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
