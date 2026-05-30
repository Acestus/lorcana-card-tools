#!/usr/bin/env python3
"""
Fetch Lorcana Player card list and extract all cards using regex-only parsing (no external deps).
Writes TSV and CSV to the target assets folder.
Usage: python3 scrape_lorcana_full.py <url> <out_prefix>
Example: python3 scrape_lorcana_full.py "https://lorcanaplayer.com/wilds-unknown-card-list-lorcana-set-12/" assets/lorcana/wilds_unknown_full
This will write <out_prefix>.tsv and <out_prefix>.csv
"""
import sys, re, os
from urllib.request import urlopen, Request

CARDNUM_RE = re.compile(r"(\d{1,4})/\d{1,4}")
RARITY_RE = re.compile(r"\b(C|UC|R|SR|L|EP|E|I|Epic|Enchanted|Iconic|Super Rare|Legendary)\b", re.I)
RARITY_MAP = {'C':'Common','UC':'Uncommon','R':'Rare','SR':'Super Rare','L':'Legendary','EP':'Epic','E':'Enchanted','I':'Iconic',
              'EPIC':'Epic','ENCHANTED':'Enchanted','ICONIC':'Iconic','SUPER RARE':'Super Rare','LEGENDARY':'Legendary'}

ANCHOR_RE = re.compile(r'<a[^>]+href=["\'](?P<h>[^"\']*/card/[^"\']*)["\'][^>]*>(?P<name>.*?)</a>', re.I|re.S)
TAG_RE = re.compile(r'<[^>]+>')


def clean_text(s):
    # remove tags, collapse whitespace
    t = TAG_RE.sub('', s)
    t = re.sub(r'\s+', ' ', t).strip()
    return t


def normalize_cardnum(val):
    try:
        n = int(val)
        return f"{n:03d}", n
    except Exception:
        return None, None


def normalize_rarity(code):
    if not code: return ''
    code = code.strip()
    txt = RARITY_MAP.get(code.upper(), code)
    return txt


def scrape(url):
    req = Request(url, headers={'User-Agent':'lorcana-scraper/1.0'})
    with urlopen(req, timeout=30) as r:
        html = r.read().decode('utf-8', errors='ignore')

    results = []
    seen = set()

    for m in ANCHOR_RE.finditer(html):
        name_html = m.group('name')
        name = clean_text(name_html)
        start = m.start()
        end = m.end()
        # find cardnum by searching backward up to 400 chars
        lookback = html[max(0, start-400):start]
        cardnum_m = CARDNUM_RE.search(lookback[::-1])
        cardnum = None
        if cardnum_m:
            # because we reversed the string, extract differently
            # just search normally instead
            cardnum_m2 = CARDNUM_RE.search(lookback)
            if cardnum_m2:
                cardnum_raw = cardnum_m2.group(1)
                cardnum, n_int = normalize_cardnum(cardnum_raw)
        if not cardnum:
            # try forward search in 200 chars
            lookfwd = html[end:end+400]
            cardnum_m2 = CARDNUM_RE.search(lookfwd)
            if cardnum_m2:
                cardnum_raw = cardnum_m2.group(1)
                cardnum, n_int = normalize_cardnum(cardnum_raw)
        # find rarity forward near anchor
        rarity = ''
        lookfwd = html[end:end+300]
        r_m = RARITY_RE.search(lookfwd)
        if r_m:
            rarity = normalize_rarity(r_m.group(1))
        # fallback: search a bit before anchor too
        if not rarity:
            lb = html[max(0,start-200):start]
            r2 = RARITY_RE.search(lb)
            if r2:
                rarity = normalize_rarity(r2.group(1))

        # ensure we have some key; use name position as fallback key
        key = cardnum or name
        if key in seen:
            continue
        seen.add(key)
        # if no cardnum, set placeholder later
        results.append({'cardnum':cardnum or '', 'name':name, 'rarity':rarity})

    # If we found entries without numeric cardnum, try to assign sequence numbers if many
    # Sort results: entries with numeric cardnum first by number, then others
    def sort_key(item):
        if item['cardnum']:
            return (0, int(item['cardnum']))
        return (1, 0)

    results_sorted = sorted(results, key=sort_key)

    # fill missing numbers sequentially after last known
    last_num = 0
    for it in results_sorted:
        if it['cardnum']:
            last_num = int(it['cardnum'])
        else:
            last_num += 1
            it['cardnum'] = f"{last_num:03d}"

    return results_sorted


def write_files(rows, out_prefix):
    tsv_path = out_prefix + '.tsv'
    csv_path = out_prefix + '.csv'
    with open(tsv_path, 'w', encoding='utf-8') as f:
        for it in rows:
            num = it['cardnum']
            name = it['name']
            rarity = it['rarity'] or ''
            # format per fabled rules: if num>204 or rarity in special, print differently
            try:
                n_int = int(num)
            except Exception:
                n_int = None
            if (n_int is not None and n_int > 204) or rarity in ('Epic','Enchanted','Iconic'):
                line = '\t'.join([num, 'FALSE', rarity, name, rarity])
            else:
                line = '\t'.join([num, 'FALSE', 'FALSE', name, rarity])
            f.write(line + '\n')
    with open(csv_path, 'w', encoding='utf-8') as f:
        for it in rows:
            num = it['cardnum']
            name = it['name'].replace('"','""')
            rarity = it['rarity'] or ''
            f.write(f'"{num}","FALSE","FALSE","{name}","{rarity}"\n')
    return tsv_path, csv_path


def main():
    if len(sys.argv) < 3:
        print('Usage: scrape_lorcana_full.py <url> <out_prefix>')
        sys.exit(1)
    url = sys.argv[1]
    out_prefix = sys.argv[2]
    os.makedirs(os.path.dirname(out_prefix), exist_ok=True)
    print('Fetching', url)
    rows = scrape(url)
    print(f'Found {len(rows)} cards')
    tsv, csv = write_files(rows, out_prefix)
    print('Wrote', tsv, csv)

if __name__ == '__main__':
    main()
