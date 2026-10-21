# build_catalog

Offline script to build `assets/catalog/catalog_v1.json` + `starter_packs.json` from:

- `raw/*.csv` (hand / LLM-normalized lists — plan Phụ lục D)
- Stable IDs in `id_registry.json` (key = `barcode:…` or `slug:…`)

## Run

```bash
cd so-gia
python3 tool/build_catalog/build_catalog.py
```

Outputs:

| File | Role |
|------|------|
| `assets/catalog/catalog_v1.json` | Bundled catalog (`catalog_version` bumped by script) |
| `assets/catalog/starter_packs.json` | Tạp hóa / Quầy rau củ–thịt / Siêu thị mini |
| `tool/build_catalog/id_registry.json` | Stable UUID registry (commit this) |
| `tool/build_catalog/build_report.md` | Counts + warnings |

## CSV columns (`raw/*.csv`)

```text
name,brand,barcode,size_text,category_id,is_weighed,pack_ids,source_note
```

- Leave `barcode` empty unless verified against packaging or Open Food Facts.
- `pack_ids`: `tap-hoa`, `rau-cu-thit`, or `tap-hoa|rau-cu-thit`.
- Weighed rows: `is_weighed=true`, `size_text=1 kg`.

## OFF dump (lookup aid only)

```text
/mnt/d9817672-fa4f-44b5-96e9-07bd39acf312/dev-tools/off-dump/en.openfoodfacts.org.products.csv.gz
```

```bash
python3 tool/build_catalog/count_893.py
```

| Metric (2026-10-18) | Value |
|---------------------|------:|
| Prefix `893` | 6,942 |
| EAN-13 | 6,260 |

Do **not** copy unverified barcodes from OFF into `raw/`.

## Quality rules

- Wrong barcode is the worst failure — prefer empty barcode.
- Do not copy images, descriptions, or prices from supermarket sites.
- Target for usable trial: ≥150 SKU; long-term ~450–500.
