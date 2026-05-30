#!/usr/bin/env python3
"""
No-deps scraper using only Python stdlib. Usage:
  python3 scrape_no_deps.py <url> output.tsv
"""
import sys, re
from html.parser import HTMLParser
try:
    from urllib.request import urlopen, Request
except Exception:
    print('urllib not available')
    raise

CARDNUM_RE = re.compile(r"(\d+)/(?:\d+)")
RARITY_RE = re.compile(r"\b(C|UC|R|SR|L|EP|E|I)\b")
RARITY_MAP = {'C':'Common','UC':'Uncommon','R':'Rare','SR':'Super Rare','L':'Legendary','EP':'Epic','E':'Enchanted','I':'Iconic'}

class TokenParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tokens = []
    def handle_starttag(self, tag, attrs):
        self.tokens.append(('start', tag, dict(attrs)))
    def handle_startendtag(self, tag, attrs):
        self.tokens.append(('start', tag, dict(attrs)))
    def handle_data(self, data):
        s = data.strip()
        if s:
            self.tokens.append(('data', s))

def fetch(url):
    req = Request(url, headers={'User-Agent':'lorcana-scraper/1.0'})
    with urlopen(req, timeout=20) as r:
        return r.read().decode('utf-8', errors='ignore')

def normalize_cardnum(val):
    try:
        n = int(val)
        return f"{n:03d}"
    except Exception:
        return None

def normalize_rarity(code):
    if not code: return ''
    return RARITY_MAP.get(code.strip(), code.strip())

def scrape_from_html(html):
    p = TokenParser()
    p.feed(html)
    toks = p.tokens
    results = []
    seen = set()
    for i, t in enumerate(toks):
        if t[0]=='start' and t[1]=='a':
            attrs = t[2]
            href = attrs.get('href','')
            if '/card/' in href:
                # find next data token for name
                name = None
                for j in range(i+1, min(i+6, len(toks))):
                    if toks[j][0]=='data':
                        name = toks[j][1]
                        break
                if not name:
                    continue
                # search backward for card number
                cardnum = None
                for k in range(i-1, max(-1, i-30), -1):
                    if toks[k][0]=='data':
                        m = CARDNUM_RE.search(toks[k][1])
                        if m:
                            cardnum = normalize_cardnum(m.group(1))
                            break
                # search forward for rarity
                rarity = ''
                for k in range(i+1, min(len(toks), i+30)):
                    if toks[k][0]=='data':
                        m = RARITY_RE.search(toks[k][1])
                        if m:
                            rarity = normalize_rarity(m.group(1))
                            break
                if cardnum and cardnum not in seen:
                    seen.add(cardnum)
                    results.append((cardnum, name, rarity))
    # if nothing found, try fallback by scanning data tokens for cardnum then next data as name
    if not results:
        for idx, tok in enumerate(toks):
            if tok[0]=='data':
                m = CARDNUM_RE.search(tok[1])
                if m:
                    num = normalize_cardnum(m.group(1))
                    # next data token is likely name
                    for j in range(idx+1, idx+6):
                        if j < len(toks) and toks[j][0]=='data':
                            name = toks[j][1]
                            results.append((num, name, ''))
                            break
    return results

def write_tsv(rows, out):
    with open(out, 'w', encoding='utf-8') as f:
        for num, name, rarity in rows:
            rarity = (rarity or '').strip()
            try:
                n_int = int(num)
            except Exception:
                n_int = None
            if (n_int is not None and n_int > 204) or rarity in ('Epic','Enchanted','Iconic'):
                line = '\t'.join([num, 'FALSE', rarity, name, rarity])
            else:
                line = '\t'.join([num, 'FALSE', 'FALSE', name, rarity])
            f.write(line + '\n')

def main():
    if len(sys.argv) < 3:
        print('Usage: scrape_no_deps.py <url> output.tsv')
        sys.exit(1)
    url = sys.argv[1]
    out = sys.argv[2]
    print('Fetching', url)
    html = fetch(url)
    rows = scrape_from_html(html)
    if not rows:
        print('No rows found')
        sys.exit(2)
    write_tsv(rows, out)
    print(f'Wrote {len(rows)} rows to {out}')

if __name__ == '__main__':
    main()
