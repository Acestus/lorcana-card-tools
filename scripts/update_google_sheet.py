#!/usr/bin/env python3
"""
Update a Google Sheet from a local CSV/TSV file using a service account.

Usage:
  python3 scripts/update_google_sheet.py --spreadsheet SPREADSHEET_ID_OR_URL \
      --file path/to/file.csv --start-row 33 --sheet "Sheet1" [--creds /path/to/sa.json]

Environment:
  Set GOOGLE_APPLICATION_CREDENTIALS or pass --creds pointing to service account JSON with Sheets API access.

Behavior:
- Clears the sheet area starting at the start row (columns A:Z) then writes the CSV rows starting at A<start-row>.
- Supports comma- or tab-delimited files (auto-detected).
"""
import argparse
import csv
import os
import sys

try:
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
except Exception:
    print('Missing Google API libraries. Install with: pip install google-api-python-client google-auth-httplib2 google-auth')
    raise

SCOPES = ['https://www.googleapis.com/auth/spreadsheets']


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--spreadsheet', required=True, help='Spreadsheet ID or URL')
    p.add_argument('--file', required=True, help='Path to CSV/TSV file')
    p.add_argument('--start-row', type=int, default=33, help='Start row in sheet (default 33)')
    p.add_argument('--sheet', default='Sheet1', help='Sheet/tab name (default Sheet1)')
    p.add_argument('--creds', default=None, help='Path to service account JSON (or set GOOGLE_APPLICATION_CREDENTIALS env var)')
    return p.parse_args()


def detect_delimiter(path):
    # quick sniff: check first line for tabs or commas
    with open(path, 'r', encoding='utf-8') as f:
        s = f.read(4096)
    if '\t' in s and (s.count('\t') > s.count(',')):
        return '\t'
    return ','


def spreadsheet_id_from(maybe_url):
    if 'docs.google.com' in maybe_url:
        # try to extract between /d/ and /
        import re
        m = re.search(r'/d/([a-zA-Z0-9-_]+)', maybe_url)
        if m:
            return m.group(1)
    return maybe_url


def main():
    args = parse_args()
    ss = spreadsheet_id_from(args.spreadsheet)
    path = args.file
    if not os.path.exists(path):
        print('File not found:', path); sys.exit(2)

    delim = detect_delimiter(path)
    rows = []
    with open(path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f, delimiter=delim)
        for r in reader:
            # strip BOM from first cell
            if r and isinstance(r[0], str) and r[0].startswith('\ufeff'):
                r[0] = r[0].lstrip('\ufeff')
            rows.append(r)

    creds_path = args.creds or os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
    if not creds_path or not os.path.exists(creds_path):
        print('Service account JSON not found. Set GOOGLE_APPLICATION_CREDENTIALS or pass --creds')
        sys.exit(3)

    creds = service_account.Credentials.from_service_account_file(creds_path, scopes=SCOPES)
    service = build('sheets', 'v4', credentials=creds)

    sheet_name = args.sheet
    start_row = args.start_row
    # clear target range A{start_row}:Z
    clear_range = f"{sheet_name}!A{start_row}:Z"
    print('Clearing range', clear_range)
    service.spreadsheets().values().clear(spreadsheetId=ss, range=clear_range, body={}).execute()

    # Prepare write range
    write_range = f"{sheet_name}!A{start_row}"
    print(f'Updating spreadsheet {ss} sheet {sheet_name} at {write_range} with {len(rows)} rows')
    body = {'values': rows}
    service.spreadsheets().values().update(spreadsheetId=ss, range=write_range, valueInputOption='RAW', body=body).execute()
    print('Update complete')

if __name__ == '__main__':
    main()
