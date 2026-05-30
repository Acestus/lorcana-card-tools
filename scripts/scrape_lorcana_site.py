#!/usr/bin/env python3
"""
Scrape Lorcana Player card list reliably and write CSV/TSV to assets/lorcana.
This script prefers requests + BeautifulSoup when available; falls back to stdlib parsing.

Usage:
  python3 scripts/scrape_lorcana_site.py <list_url> <out_dir>

Example:
  python3 scripts/scrape_lorcana_site.py \
    "https://lorcanaplayer.com/wilds-unknown-card-list-lorcana-set-12/" assets/lorcana

Outputs: out_dir/<slug>.tsv and .csv
"""
import sys
import os
import re
import time
from urllib.parse import urljoin, urlparse

try:
    import requests
    from bs4 import BeautifulSoup
    HAS_BS = True
except Exception:
    HAS_BS = False
    import urllib.request


def slug_from_url(url):
    p = urlparse(url)
    slug = os.path.basename(p.path.strip('/')) or 'cards'
    return slug


CARDNUM_RE = re.compile(r"(\d{1,4})/\d{1,4}")
RARITY_RE = re.compile(r"\b(C|UC|R|SR|L|EP|E|I|Epic|Enchanted|Iconic|Super Rare|Legendary)\b", re.I)
RARITY_MAP = {'C':'Common','UC':'Uncommon','R':'Rare','SR':'Super Rare','L':'Legendary','EP':'Epic','E':'Enchanted','I':'Iconic'}


def fetch_text(url, headers=None, timeout=20):
    if HAS_BS:
        resp = requests.get(url, headers=headers or {'User-Agent':'lorcana-scraper/1.0'}, timeout=timeout)
        resp.raise_for_status()
        return resp.text
    else:
        req = urllib.request.Request(url, headers={'User-Agent':'lorcana-scraper/1.0'})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read().decode('utf-8', errors='ignore')


def find_card_links(html, base_url):
    links = []
    if HAS_BS:
        soup = BeautifulSoup(html, 'html.parser')
        for a in soup.find_all('a', href=True):
            href = a['href']
            if '/card/' in href:
                full = urljoin(base_url, href)
                links.append((full, a.get_text(strip=True)))
    else:
        # regex search for hrefs containing /card/
        for m in re.finditer(r'href=["\']([^"\']*/card/[^"\']*)', html, re.I):
            href = m.group(1)
            full = urljoin(base_url, href)
            # try to capture anchor text nearby
            # find the closing > before the anchor text and capture until </a>
            # fallback to URL
            links.append((full, ''))
    # dedupe preserving order
    seen = set(); out = []
    for u, t in links:
        if u not in seen:
            seen.add(u); out.append((u, t))
    return out


def extract_from_card_page(html, url):
    # Try to extract card number, name, rarity
    name = ''
    cardnum = ''
    rarity = ''
    if HAS_BS:
        soup = BeautifulSoup(html, 'html.parser')
        # Name: look for h1 or title
        h1 = soup.find(['h1','h2'])
        if h1:
            name = h1.get_text(strip=True)
        if not name and soup.title:
            name = soup.title.string.strip()
        # card number and rarity: search text
        txt = soup.get_text(' ', strip=True)
        m = CARDNUM_RE.search(txt)
        if m:
            cardnum = f"{int(m.group(1)):03d}"
        r = RARITY_RE.search(txt)
        if r:
            rarity = RARITY_MAP.get(r.group(1).upper(), r.group(1))
    else:
        txt = html
        m = CARDNUM_RE.search(txt)
        if m:
            cardnum = f"{int(m.group(1)):03d}"
        # name: try <title> tag
        m2 = re.search(r'<title>(.*?)</title>', txt, re.I|re.S)
        if m2:
            name = re.sub(r'\s+', ' ', re.sub('<[^>]+>', '', m2.group(1))).strip()
        r = RARITY_RE.search(txt)
        if r:
            rarity = RARITY_MAP.get(r.group(1).upper(), r.group(1))
    return cardnum, name, rarity


def extract_from_list_page(html):
    # When card links are not present, try to extract blocks: Card #, Name, Rarity
    results = []
    # split on known separators like <img> blocks etc
    # fallback to searching sequential patterns of "n/204" then name then rarity
    text = re.sub(r'<[^>]+>', ' ', html)
    tokens = [t.strip() for t in re.split(r'\n|\r|\t', text) if t.strip()]
    for i, tok in enumerate(tokens):
        m = CARDNUM_RE.search(tok)
        if m:
            num = f"{int(m.group(1)):03d}"
            # name might be next non-empty token
            name = tokens[i+1] if i+1 < len(tokens) else ''
            # find rarity in following few tokens
            rarity = ''
            for j in range(i+1, min(i+6, len(tokens))):
                r = RARITY_RE.search(tokens[j])
                if r:
                    rarity = RARITY_MAP.get(r.group(1).upper(), r.group(1))
                    break
            results.append((num, name, rarity))
    return results


def write_files(rows, out_dir, slug):
    os.makedirs(out_dir, exist_ok=True)
    tsv = os.path.join(out_dir, f"{slug}.tsv")
    csv = os.path.join(out_dir, f"{slug}.csv")
    with open(tsv, 'w', encoding='utf-8') as f:
        for num, name, rarity in rows:
            # apply fabled rules
            try:
                n = int(num)
            except Exception:
                n = None
            if (n is not None and n > 204) or rarity in ('Epic','Enchanted','Iconic'):
                line = '\t'.join([num, 'FALSE', rarity, name, rarity])
            else:
                line = '\t'.join([num, 'FALSE', 'FALSE', name, rarity])
            f.write(line + '\n')
    import csv as _csv
    with open(csv, 'w', encoding='utf-8', newline='') as f:
        w = _csv.writer(f)
        for num, name, rarity in rows:
            w.writerow([num, 'FALSE', 'FALSE', name, rarity])
    return tsv, csv


def main():
    if len(sys.argv) < 3:
        print('Usage: scrape_lorcana_site.py <list_url> <out_dir>')
        sys.exit(1)
    url = sys.argv[1]
    out_dir = sys.argv[2]
    slug = slug_from_url(url)
    print('Fetching list page...')
    html = fetch_text(url)

    links = find_card_links(html, url)
    rows = []
    if links:
        print(f'Found {len(links)} card links; crawling detail pages (this may take a moment)')
        for idx, (link, anchor_text) in enumerate(links, start=1):
            try:
                page = fetch_text(link)
                cardnum, name, rarity = extract_from_card_page(page, link)
                # prefer anchor_text name if extracted name is empty
                if not name and anchor_text:
                    name = anchor_text
                if not cardnum:
                    # try to extract from anchor_text
                    m = CARDNUM_RE.search(anchor_text)
                    if m:
                        cardnum = f"{int(m.group(1)):03d}"
                if not name:
                    name = anchor_text or ''
                if not rarity:
                    rarity = ''
                rows.append((cardnum or f"{idx:03d}", name, rarity))
            except Exception as e:
                print('Error fetching', link, e)
            time.sleep(0.08)
    else:
        print('No card links found; falling back to inline parsing')
        rows = extract_from_list_page(html)

    if not rows:
        print('No cards discovered; exiting')
        sys.exit(2)

    tsv_path, csv_path = write_files(rows, out_dir, slug)
    print('Wrote', tsv_path, csv_path)

if __name__ == '__main__':
    main()
