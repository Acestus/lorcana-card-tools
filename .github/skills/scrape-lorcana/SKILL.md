Skill: scrape-lorcana

Trigger: "scrape lorcana"

Description: Run the Lorcana Player list scraper and write CSV/TSV to assets/lorcana. This skill is a thin caller that runs the script in scripts/ and commits the result.

Run:

  # Example: scrape Wilds Unknown (set 12)
  python3 scripts/scrape_lorcana_site.py "https://lorcanaplayer.com/wilds-unknown-card-list-lorcana-set-12/" assets/lorcana

Post-processing (optional): commit and push generated files

  git add assets/lorcana/*.csv assets/lorcana/*.tsv && git commit -m "Add scraped Lorcana set data" && git push

Notes:
- The script uses requests + BeautifulSoup if installed; otherwise it falls back to stdlib parsing. For best results, install dependencies:
    pip install requests beautifulsoup4
- Running the crawler may take a minute as it fetches card detail pages. Rate-limited to be polite.
