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
