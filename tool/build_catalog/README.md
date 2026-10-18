# build_catalog

Offline script to build `assets/catalog/catalog_v1.json` + `starter_packs.json` from:

- `raw/*.csv` (hand / LLM-normalized lists — Phụ lục D)
- Open Food Facts dump filtered to barcodes starting with `893` (Vietnam GS1)

## OFF dump (local)

Default path (data disk):

```text
/mnt/d9817672-fa4f-44b5-96e9-07bd39acf312/dev-tools/off-dump/en.openfoodfacts.org.products.csv.gz
```

Count VN barcodes only:

```bash
python3 count_893.py
```

## Count result (2026-10-18)

| Metric | Value |
|--------|------:|
| Dump size | 1.19 GiB |
| Total rows | 4,532,767 |
| Prefix `893` | **6,942** |
| of which EAN-13 (`len=13`) | **6,260** |
| with `product_name` | 6,282 (90.5%) |
| with `brands` | 3,551 (51.2%) |
| with `quantity` | 1,928 (27.8%) |

Report file: `/mnt/.../dev-tools/off-dump/count_893_report.txt`

Implication for catalog (~220 packaged VN SKUs): OFF has thousands of `893*` codes, but many are junk length / non-grocery / non-VN labels. Use as lookup aid; hand-verify barcodes; leave blank when unsure.

## Status

Khung P9.2 — script đầy đủ sẽ điền ở P9; hiện có `categories.json` + `count_893.py` (+ báo cáo 893).
