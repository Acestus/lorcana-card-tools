#!/usr/bin/env python3
"""
Scrape a Lorcana Player card list page and output TSV suitable for import.
Usage: python3 scrape_lorcana.py <url> output.tsv

Writes TSV columns: number, FALSE, FALSE, name, rarity
"""
import sys
import re
import argparse
from html import unescape

try:
    import requests
    from bs4 import BeautifulSoup, NavigableString
except Exception:
    print("Missing dependencies. Install with: pip install requests beautifulsoup4")
    raise

RARITY_MAP = {
    'C': 'Common',
    'UC': 'Uncommon',
    'R': 'Rare',
    'SR': 'Super Rare',
    'L': 'Legendary',
    'EP': 'Epic',
    'E': 'Enchanted',
    'I': 'Iconic'
}

CARDNUM_RE = re.compile(r"(\d+)/(?:\d+)")
RARITY_RE = re.compile(r"\b(C|UC|R|SR|L|EP|E|I)\b")


def find_nearby_text(node, pattern, max_steps=25):
    # search previous siblings, parent text, then next siblings
    # returns first matching group or None
    steps = 0
    # previous siblings
    sib = node.previous_sibling
    while sib is not None and steps < max_steps:
        txt = ''
        if isinstance(sib, NavigableString):
            txt = str(sib)
        else:
            txt = sib.get_text(separator=' ', strip=True)
        m = pattern.search(txt)
        if m:
            return m.group(1) if m.groups() else m.group(0)
        sib = sib.previous_sibling
        steps += 1

    # parent text
    parent = node.parent
    if parent is not None:
        txt = parent.get_text(separator=' ', strip=True)
        m = pattern.search(txt)
        if m:
            return m.group(1) if m.groups() else m.group(0)

    # next siblings
    steps = 0
    sib = node.next_sibling
    while sib is not None and steps < max_steps:
        txt = ''
        if isinstance(sib, NavigableString):
            txt = str(sib)
        else:
            txt = sib.get_text(separator=' ', strip=True)
        m = pattern.search(txt)
        if m:
            return m.group(1) if m.groups() else m.group(0)
        sib = sib.next_sibling
        steps += 1

    return None


def normalize_cardnum(val):
    try:
        n = int(val)
        return f"{n:03d}"
    except Exception:
        return None


def normalize_rarity(code):
    code = code.strip()
    return RARITY_MAP.get(code, code)


def scrape(url):
    print(f"Fetching: {url}")
    resp = requests.get(url, headers={"User-Agent": "lorcana-scraper/1.0"}, timeout=20)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, 'html.parser')

    results = []
    seen_nums = set()

    # find card links (likely /card/)
    anchors = soup.find_all('a', href=re.compile(r'/card/'))
    for a in anchors:
        name = a.get_text(strip=True)
        if not name:
            continue
        # find card number nearby
        cnum_raw = find_nearby_text(a, CARDNUM_RE)
        if not cnum_raw:
            # try searching page for a pattern that includes name
            # skip if we can't find card number
            # continue
            pass
        else:
            cnum = normalize_cardnum(cnum_raw)
            if not cnum:
                continue

        # find rarity nearby
        r_raw = find_nearby_text(a, RARITY_RE)
        rarity = normalize_rarity(r_raw) if r_raw else ''

        if cnum and cnum not in seen_nums:
            seen_nums.add(cnum)
            results.append((cnum, name, rarity))

    # fallback: look for any textual occurrences like '1/204' then following name
    if not results:
        text = soup.get_text('\n')
        for m in CARDNUM_RE.finditer(text):
            n = normalize_cardnum(m.group(1))
            # naive: get following line as name
            rest = text[m.end():].strip().splitlines()
            if rest:
                name = rest[0].strip()
                results.append((n, name, ''))

    return results


def write_tsv(rows, out_path):
    """
    Match the requested fabled style sample:
    - For regular cards (1..204): number, FALSE, FALSE, name, rarity
    - For special cards (above 204) or when rarity is Epic/Enchanted/Iconic:
      number, FALSE, <Rarity>, name, <Rarity>
    """
    with open(out_path, 'w', encoding='utf-8') as f:
        for num, name, rarity in rows:
            rarity = (rarity or '').strip()
            # try interpret numeric value
            try:
                n_int = int(num)
            except Exception:
                n_int = None

            if (n_int is not None and n_int > 204) or rarity in ('Epic', 'Enchanted', 'Iconic'):
                # e.g. 205\tFALSE\tEpic\tTiana – Warm and Happy\tEpic
                line = '\t'.join([num, 'FALSE', rarity, unescape(name), rarity])
            else:
                # e.g. 001\tFALSE\tFALSE\tThomas – ...\tCommon
                line = '\t'.join([num, 'FALSE', 'FALSE', unescape(name), rarity])

            f.write(line + '\n')


def main():
    p = argparse.ArgumentParser(description='Scrape Lorcana Player card list to TSV')
    p.add_argument('url', help='Lorcana Player card list URL')
    p.add_argument('output', help='Output TSV path')
    args = p.parse_args()

    rows = scrape(args.url)
    if not rows:
        print('No cards found. Aborting.')
        sys.exit(2)

    write_tsv(rows, args.output)
    print(f'Wrote {len(rows)} rows to {args.output}')


if __name__ == '__main__':
    main()
