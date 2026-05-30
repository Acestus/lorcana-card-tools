Skill: scrape-lorcana

Trigger: "scrape lorcana"

Description: Run the Lorcana Player list scraper and write CSV/TSV to assets/lorcana. This skill is a thin caller that runs the script in scripts/ and commits the result.

Run:

  # Example: scrape Wilds Unknown (set 12)
  python3 scripts/scrape_lorcana_site.py "https://lorcanaplayer.com/wilds-unknown-card-list-lorcana-set-12/" assets/lorcana

Confidence bar (automated header)

This repository includes a small helper that renders a 20-character-wide confidence bar used in skill headers and operator prompts. The bar uses two Unicode symbols:

- Filled: █ (U+2588 FULL BLOCK)
- Empty: ░ (U+2591 LIGHT SHADE)

Format (20-character bar):

  <TICKET> — Ticket Title
  ━━━━━━━━━━━━━━━━━━━━━━━━
  Confidence: ████░░░░░░░░░░░░░░░░ 20% (need 95%)

Scale: filled_chars = round(percentage / 100 * 20)

At 95%+ the trailing text becomes: ✓ ready to investigate

Usage (helper script):

  python3 scripts/confidence_bar.py <ticket-id> "Ticket Title" <percentage> [threshold]

Example:
  python3 scripts/confidence_bar.py INFRA-123 "Investigate network" 20 95

Integration rules

- Re-render the full header block (including the bar) after every assistant answer and after every phase transition.
- Gate: Do not proceed to execution steps unless confidence >= threshold (default 95%). If confidence is below threshold, ask the operator to explicitly waive the gate before executing.
- At confidence >= threshold replace "(need 95%)" with "✓ ready to investigate".

Post-processing (optional): commit and push generated files

  git add assets/lorcana/*.csv assets/lorcana/*.tsv && git commit -m "Add scraped Lorcana set data" && git push

Notes:
- The scraper uses requests + BeautifulSoup if installed; otherwise it falls back to stdlib parsing. For best results, install dependencies:
    pip install requests beautifulsoup4
- Running the crawler may take a minute as it fetches card detail pages. Rate-limited to be polite.

Updating Google Sheets via API

This skill can push CSV/TSV output directly into a Google Sheet using a service account. A helper script is provided:

  python3 scripts/update_google_sheet.py --spreadsheet <SPREADSHEET_ID_OR_URL> --file scripts/wilds_unknown_paste.csv --start-row 33 --sheet "Sheet1" [--creds /path/to/sa.json]

Setup (Service Account)

1. Create a Google Cloud service account and JSON key with the "Google Sheets API" enabled.
2. Share the target Google Sheet with the service account's client_email (read/write).
3. Either set the environment variable:

   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

   or pass --creds /path/to/service-account.json to the script.

The script will clear the sheet area starting at the start row (columns A:Z) and write the CSV rows beginning at that row.

Dependencies:

  pip install google-api-python-client google-auth-httplib2 google-auth

Security:
- Do NOT commit service account credentials to the repository. Keep them local or in CI secrets.

Gate & Confidence

Before the skill writes to a live sheet, re-render the confidence header and ensure confidence >= threshold (default 95%). If below threshold, the operator must explicitly waive the gate.

Examples

  # Scrape and push
  python3 scripts/scrape_lorcana_site.py "https://lorcanaplayer.com/wilds-unknown-card-list-lorcana-set-12/" assets/lorcana
  python3 scripts/update_google_sheet.py --spreadsheet "https://docs.google.com/spreadsheets/d/16ykFi413edBFxDRG__0rrBqfHOXYGFgt3p3PD0hq704/" --file assets/lorcana/wilds-unknown-card-list-lorcana-set-12.csv --start-row 33 --sheet "Card List"
