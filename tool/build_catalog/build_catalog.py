#!/usr/bin/env python3
"""Build assets/catalog/catalog_v1.json + starter_packs.json from raw/*.csv.

Stable IDs are kept in id_registry.json (key = barcode if present, else slug).
Does not invent barcodes — empty barcode stays null.
"""

from __future__ import annotations

import csv
import json
import re
import sys
import unicodedata
import uuid
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = Path(__file__).resolve().parent
RAW_DIR = TOOL / "raw"
REGISTRY_PATH = TOOL / "id_registry.json"
CATEGORIES_PATH = ROOT / "assets" / "catalog" / "categories.json"
OUT_CATALOG = ROOT / "assets" / "catalog" / "catalog_v1.json"
OUT_PACKS = ROOT / "assets" / "catalog" / "starter_packs.json"
OUT_REPORT = TOOL / "build_report.md"

UNIT_TYPES = {"ml", "l", "g", "kg", "piece"}
PACK_META = {
    "tap-hoa": {
        "name": "Tạp hóa",
        "description": "Nhu yếu phẩm đóng gói, gia dụng, đồ khô",
    },
    "rau-cu-thit": {
        "name": "Quầy rau củ - thịt",
        "description": "Rau, củ, trái cây, thịt, cá, trứng, gia vị cân",
    },
    "sieu-thi-mini": {
        "name": "Siêu thị mini",
        "description": "Gộp Tạp hóa + Rau củ - thịt",
        "includes": ["tap-hoa", "rau-cu-thit"],
    },
}


def strip_diacritics(text: str) -> str:
    nfkd = unicodedata.normalize("NFD", text)
    return "".join(c for c in nfkd if unicodedata.category(c) != "Mn")


def slug_key(name: str, brand: str | None, category_id: str, size_text: str) -> str:
    parts = [
        strip_diacritics(name).lower().strip(),
        strip_diacritics(brand or "").lower().strip(),
        category_id,
        strip_diacritics(size_text).lower().strip(),
    ]
    raw = "|".join(parts)
    raw = re.sub(r"\s+", " ", raw)
    return raw


def ean13_checksum_ok(code: str) -> bool:
    if not code.isdigit() or len(code) != 13:
        return False
    digits = [int(c) for c in code]
    s = sum(digits[i] * (1 if i % 2 == 0 else 3) for i in range(12))
    check = (10 - (s % 10)) % 10
    return check == digits[12]


def parse_size(size_text: str, is_weighed: bool) -> tuple[float | None, str]:
    if is_weighed:
        return 1.0, "kg"
    s = (size_text or "").strip().lower().replace(",", ".")
    if not s:
        return None, "piece"
    m = re.match(
        r"^(\d+(?:\.\d+)?)\s*(ml|l|g|kg|piece|pcs|pc)?\b",
        s,
    )
    if not m:
        return None, "piece"
    size = float(m.group(1))
    unit_raw = m.group(2)
    unit = {
        None: None,
        "ml": "ml",
        "l": "l",
        "g": "g",
        "kg": "kg",
        "piece": "piece",
        "pcs": "piece",
        "pc": "piece",
    }.get(unit_raw)
    if unit is None:
        return None, "piece"
    return size, unit


def load_categories() -> set[str]:
    data = json.loads(CATEGORIES_PATH.read_text(encoding="utf-8"))
    return {c["id"] for c in data["categories"]}


def load_registry() -> dict[str, str]:
    if not REGISTRY_PATH.exists():
        return {}
    return json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))


def save_registry(reg: dict[str, str]) -> None:
    REGISTRY_PATH.write_text(
        json.dumps(dict(sorted(reg.items())), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def read_raw_rows() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    files = sorted(RAW_DIR.glob("*.csv"))
    if not files:
        raise SystemExit(f"No CSV files in {RAW_DIR}")
    for path in files:
        with path.open(encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            required = {
                "name",
                "brand",
                "barcode",
                "size_text",
                "category_id",
                "is_weighed",
                "pack_ids",
                "source_note",
            }
            if not required.issubset(set(reader.fieldnames or [])):
                raise SystemExit(f"{path.name}: missing columns, need {sorted(required)}")
            for i, row in enumerate(reader, start=2):
                name = (row.get("name") or "").strip()
                if not name:
                    continue
                rows.append({k: (row.get(k) or "").strip() for k in required})
                rows[-1]["_file"] = path.name
                rows[-1]["_line"] = str(i)
    return rows


def resolve_id(reg: dict[str, str], key: str) -> str:
    if key in reg:
        return reg[key]
    new_id = str(uuid.uuid4())
    reg[key] = new_id
    return new_id


def build() -> None:
    categories = load_categories()
    registry = load_registry()
    raw_rows = read_raw_rows()

    products: list[dict] = []
    pack_items: dict[str, list[dict]] = defaultdict(list)
    errors: list[str] = []
    warnings: list[str] = []
    by_cat: Counter[str] = Counter()
    seen_barcode: dict[str, str] = {}
    missing_barcode = 0
    missing_size = 0

    for row in raw_rows:
        name = row["name"]
        brand = row["brand"] or None
        barcode_raw = row["barcode"]
        barcode = barcode_raw if barcode_raw else None
        category_id = row["category_id"]
        is_weighed = row["is_weighed"].lower() in {"1", "true", "yes", "y"}
        pack_ids = [p.strip() for p in row["pack_ids"].split("|") if p.strip()]
        size_text = row["size_text"]
        source_note = row["source_note"]

        if category_id not in categories:
            errors.append(f"{row['_file']}:{row['_line']} unknown category_id={category_id}")
            continue

        if barcode:
            if len(barcode) == 13 and not ean13_checksum_ok(barcode):
                errors.append(
                    f"{row['_file']}:{row['_line']} bad EAN-13 checksum: {barcode}"
                )
                continue
            if barcode in seen_barcode:
                errors.append(
                    f"{row['_file']}:{row['_line']} duplicate barcode {barcode} "
                    f"(also {seen_barcode[barcode]})"
                )
                continue
            seen_barcode[barcode] = name
            key = f"barcode:{barcode}"
        else:
            missing_barcode += 1
            key = f"slug:{slug_key(name, brand, category_id, size_text or ('1 kg' if is_weighed else ''))}"

        unit_size, unit_type = parse_size(size_text, is_weighed)
        if unit_type not in UNIT_TYPES:
            errors.append(f"{row['_file']}:{row['_line']} bad unit_type for {name}")
            continue
        if unit_size is None and not is_weighed:
            missing_size += 1
            warnings.append(f"{row['_file']}:{row['_line']} missing size for {name}")

        pid = resolve_id(registry, key)
        product = {
            "id": pid,
            "barcode": barcode,
            "name": name,
            "brand": brand,
            "unit_size": unit_size,
            "unit_type": unit_type,
            "category_id": category_id,
            "is_weighed": is_weighed,
            "source": "seed",
        }
        products.append(product)
        by_cat[category_id] += 1

        for pack_id in pack_ids:
            if pack_id not in PACK_META:
                errors.append(
                    f"{row['_file']}:{row['_line']} unknown pack_id={pack_id}"
                )
                continue
            # uncommon items: mark default_selected false via trailing '!'
            selected = True
            clean_pack = pack_id
            pack_items[clean_pack].append(
                {"catalog_id": pid, "default_selected": selected}
            )

        if source_note.lower().startswith("off") and barcode is None:
            warnings.append(
                f"{row['_file']}:{row['_line']} OFF note but empty barcode: {name}"
            )

    if errors:
        print("BUILD FAILED:", file=sys.stderr)
        for e in errors:
            print(" -", e, file=sys.stderr)
        raise SystemExit(1)

    # Dedupe pack items by catalog_id (keep first)
    for pack_id, items in list(pack_items.items()):
        seen: set[str] = set()
        deduped = []
        for it in items:
            if it["catalog_id"] in seen:
                continue
            seen.add(it["catalog_id"])
            deduped.append(it)
        pack_items[pack_id] = deduped

    packs_out = []
    for pack_id, meta in PACK_META.items():
        entry: dict = {
            "id": pack_id,
            "name": meta["name"],
            "description": meta["description"],
        }
        if "includes" in meta:
            entry["includes"] = meta["includes"]
            entry["items"] = []
        else:
            entry["items"] = pack_items.get(pack_id, [])
        packs_out.append(entry)

    # Validate includes target packs exist; merge validation for leaf items only
    all_leaf_ids = {p["id"] for p in products}
    for pack in packs_out:
        for it in pack.get("items", []):
            if it["catalog_id"] not in all_leaf_ids:
                raise SystemExit(f"pack {pack['id']} unknown catalog_id {it['catalog_id']}")

    catalog = {
        "catalog_version": 2,
        "generated_at": date.today().isoformat(),
        "products": products,
    }
    packs_file = {"pack_version": 1, "packs": packs_out}

    OUT_CATALOG.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    OUT_PACKS.write_text(
        json.dumps(packs_file, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    save_registry(registry)

    report_lines = [
        "# build_report",
        "",
        f"- generated_at: {catalog['generated_at']}",
        f"- catalog_version: {catalog['catalog_version']}",
        f"- total products: {len(products)}",
        f"- missing barcode: {missing_barcode}",
        f"- missing unit_size (non-weighed): {missing_size}",
        f"- warnings: {len(warnings)}",
        "",
        "## By category",
        "",
    ]
    for cid, n in sorted(by_cat.items(), key=lambda x: (-x[1], x[0])):
        report_lines.append(f"- `{cid}`: {n}")
    report_lines.append("")
    report_lines.append("## Packs")
    report_lines.append("")
    for pack in packs_out:
        if "includes" in pack:
            report_lines.append(f"- `{pack['id']}`: includes {pack['includes']}")
        else:
            report_lines.append(f"- `{pack['id']}`: {len(pack['items'])} items")
    if warnings:
        report_lines.append("")
        report_lines.append("## Warnings")
        report_lines.append("")
        for w in warnings[:50]:
            report_lines.append(f"- {w}")
    OUT_REPORT.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    print(f"Wrote {OUT_CATALOG} ({len(products)} products)")
    print(f"Wrote {OUT_PACKS}")
    print(f"Wrote {OUT_REPORT}")
    print(f"Updated {REGISTRY_PATH} ({len(registry)} keys)")


if __name__ == "__main__":
    build()
