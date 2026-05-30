#!/usr/bin/env python3
"""
Simple confidence bar renderer.
Usage: python3 scripts/confidence_bar.py <ticket-id> "Ticket Title" <percentage> [threshold]
Prints a small header block with a 20-char bar using █ and ░.
"""
import sys

def render_bar(pct, width=20):
    try:
        pct_f = float(pct)
    except Exception:
        pct_f = 0.0
    filled = round(pct_f / 100.0 * width)
    filled = max(0, min(width, filled))
    return "█" * filled + "░" * (width - filled)


def main():
    if len(sys.argv) < 4:
        print('Usage: confidence_bar.py <ticket-id> "Ticket Title" <percentage> [threshold]')
        sys.exit(1)
    ticket = sys.argv[1]
    title = sys.argv[2]
    pct = float(sys.argv[3])
    threshold = float(sys.argv[4]) if len(sys.argv) > 4 else 95.0

    bar = render_bar(pct)
    pct_str = f"{round(pct)}%"
    status = f"(need {int(threshold)}%)"
    if pct >= threshold:
        status = "✓ ready to investigate"

    header_line = f"{ticket} — {title}"
    sep = "━━━━━━━━━━━━━━━━━━━━━━━━"  # visual separator
    print(header_line)
    print(sep)
    print(f"Confidence: {bar} {pct_str} {status}")

if __name__ == '__main__':
    main()
