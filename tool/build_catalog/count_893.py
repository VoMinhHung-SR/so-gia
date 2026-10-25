#!/usr/bin/env python3
"""Count Open Food Facts products whose code starts with 893 (Vietnam GS1).

Streams the official CSV.gz dump — does not load the full file into memory.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import sys
from collections import Counter
from pathlib import Path

# OFF rows can embed huge fields (ingredients / images JSON).
csv.field_size_limit(sys.maxsize)

DEFAULT_DUMP = Path(
    "/mnt/d9817672-fa4f-44b5-96e9-07bd39acf312/dev-tools/off-dump/"
    "en.openfoodfacts.org.products.csv.gz"
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dump",
        type=Path,
        default=DEFAULT_DUMP,
        help="Path to en.openfoodfacts.org.products.csv.gz",
    )
    parser.add_argument(
        "--prefix",
        default="893",
        help="Barcode prefix to count (default: 893)",
    )
    parser.add_argument(
        "--sample",
        type=int,
        default=15,
        help="Print N sample product names for the prefix",
    )
    args = parser.parse_args()

    if not args.dump.exists():
        print(f"ERROR: dump not found: {args.dump}", file=sys.stderr)
        return 1

    total = 0
    matched = 0
    with_name = 0
    with_quantity = 0
    with_brands = 0
    code_len = Counter()
    samples: list[tuple[str, str, str]] = []

    # OFF CSV is tab-separated.
    with gzip.open(args.dump, "rt", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        if not reader.fieldnames or "code" not in reader.fieldnames:
            print(
                f"ERROR: unexpected header. fields={reader.fieldnames[:20] if reader.fieldnames else None}",
                file=sys.stderr,
            )
            return 1

        for row in reader:
            total += 1
            code = (row.get("code") or "").strip()
            if not code.startswith(args.prefix):
                continue
            matched += 1
            code_len[len(code)] += 1
            name = (row.get("product_name") or row.get("product_name_en") or "").strip()
            brands = (row.get("brands") or "").strip()
            quantity = (row.get("quantity") or "").strip()
            if name:
                with_name += 1
            if brands:
                with_brands += 1
            if quantity:
                with_quantity += 1
            if len(samples) < args.sample and name:
                samples.append((code, name, brands))

            if total % 500_000 == 0:
                print(f"... scanned {total:,} rows, matched {matched:,}", file=sys.stderr)

    print("=== Open Food Facts barcode prefix count ===")
    print(f"dump:     {args.dump}")
    print(f"size:     {args.dump.stat().st_size / (1024**3):.2f} GiB")
    print(f"prefix:   {args.prefix}")
    print(f"total_rows: {total:,}")
    print(f"matched:    {matched:,}")
    if matched:
        print(f"  with product_name: {with_name:,} ({100 * with_name / matched:.1f}%)")
        print(f"  with brands:       {with_brands:,} ({100 * with_brands / matched:.1f}%)")
        print(f"  with quantity:     {with_quantity:,} ({100 * with_quantity / matched:.1f}%)")
        print("  code length hist:")
        for length, n in sorted(code_len.items()):
            print(f"    {length}: {n:,}")
    print("samples:")
    for code, name, brands in samples:
        print(f"  {code} | {name} | {brands}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
