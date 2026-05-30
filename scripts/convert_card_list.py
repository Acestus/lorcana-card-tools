#!/usr/bin/env python3
"""
Convert Lorcana detailed TSV to fabled TSV format.
Usage: convert_card_list.py input.tsv output.tsv
"""
import sys, csv

if len(sys.argv) != 3:
    print('Usage: {} input.tsv output.tsv'.format(sys.argv[0]))
    sys.exit(1)

INPUT = sys.argv[1]
OUTPUT = sys.argv[2]

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

with open(INPUT, 'r', encoding='utf-8', newline='') as inf, open(OUTPUT, 'w', encoding='utf-8', newline='') as outf:
    reader = csv.reader(inf, delimiter='\t')
    writer = outf
    # skip header if present
    try:
        header = next(reader)
    except StopIteration:
        sys.exit(0)

    for row in reader:
        if len(row) < 3:
            continue
        # card number is column 2 ($2), name is column 3 ($3), rarity is column 6 ($6)
        cardnum_raw = row[1] if len(row) > 1 else ''
        cardnum_raw = cardnum_raw.replace('/204','').strip()
        try:
            n = int(cardnum_raw)
            cardnum = f"{n:03d}"
        except Exception:
            continue
        name = row[2].strip() if len(row) > 2 else ''
        rarity_code = row[5].strip() if len(row) > 5 else ''
        rarity = RARITY_MAP.get(rarity_code, rarity_code)
        line = '\t'.join([cardnum, 'FALSE', 'FALSE', name, rarity])
        writer.write(line + '\n')

print('Wrote converted file to', OUTPUT)
