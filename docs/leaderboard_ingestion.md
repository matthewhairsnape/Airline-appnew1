# Leaderboard Data Ingestion

This guide explains how to transform curated survey exports into the Supabase tables that power the Flutter leaderboard screens.

## 1. Prepare the CSV

Create a UTF-8 CSV with the following headers (case-insensitive):

| Column            | Required | Description                                                                 |
| ----------------- | -------- | --------------------------------------------------------------------------- |
| `airline_iata`    | ✅       | IATA code in the Supabase `airlines` table (e.g. `EK`, `QR`).               |
| `category`        | ✅       | One of the UI tabs (`Overall`, `Wi-Fi Experience`, `Seat Comfort`, etc.).   |
| `leaderboard_score` | ✅     | Score to display (percentage or composite number).                          |
| `leaderboard_rank` | ❌      | 1-based rank. If omitted the script auto-sorts by row order per category.   |
| `travel_class`    | ❌       | Cabin class (Business, Economy, Premium Economy, First). Can be provided via CLI instead. |
| `avg_rating`      | ❌       | Average rating (0-5).                                                        |
| `review_count`    | ❌       | Count of responses that fed the score.                                      |
| `positive_count`  | ❌       | Positive responses for quick validation.                                    |
| `negative_count`  | ❌       | Negative responses.                                                          |
| `positive_ratio`  | ❌       | Percentage positive (0-100).                                                |
| any other column  | ❌       | Captured as a metric breakdown (`leaderboard_metrics.metric_key`).          |

Tips:
- Keep one row per airline/category combination.
- If your raw export is in Excel or multiple sheets, normalize it in the spreadsheet app first.
- Multiple Travel Classes = separate CSV runs (or include the `travel_class` column per row).

## 2. Environment

The ingestion helper uses the Supabase REST API, so export the service credentials in your shell:

```bash
export SUPABASE_URL="https://<project-id>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOi..."  # never commit this value
```

## 3. Install Python Dependencies

The script relies on `requests` and `python-dateutil`. Install them once inside the repo:

```bash
python -m pip install --upgrade requests python-dateutil
```

## 4. Run the Ingestion Helper

```bash
python scripts/leaderboard/ingest_leaderboard_data.py \
  --csv data/leaderboard/business_overall.csv \
  --travel-class "Business" \
  --label "Business Leaderboard 2025-11 upload" \
  --reporting-start 2025-10-01 \
  --reporting-end 2025-10-31
```

Flags:
- `--csv` (required) path to your prepared CSV.
- `--travel-class` if not present per row.
- `--label` optional snapshot label shown in Supabase.
- `--reporting-start` / `--reporting-end` (YYYY-MM-DD) for lineage.
- `--notes` freeform text stored with the snapshot.
- `--dry-run` validates parsing and airline lookups without writing.

The script will:
1. Create a row in `leaderboard_snapshots`.
2. Insert the rankings into `leaderboard_rankings` (inactive).
3. Store numeric extras in `leaderboard_metrics`.
4. Activate the snapshot via `activate_leaderboard_snapshot` (deactivates prior active rows for the same travel class/category).

## 5. Verifying in Supabase

- Check `leaderboard_snapshots` for the new entry.
- Confirm `leaderboard_rankings` rows have `is_active = true`.
- Inspect `leaderboard_metrics` for extra breakdowns.
- Refresh the leaderboard screen in the Flutter app; it now queries `leaderboard_rankings` filtered to active rows.

## 6. Common Errors

| Error | Fix |
| ----- | --- |
| `Airline with IATA code ... not found` | Add the airline to the `airlines` table first (with `logo_url`). |
| `Environment variable SUPABASE_URL is required` | Make sure both env vars are exported in your shell. |
| `Supabase request failed (401/403)` | Credentials are incorrect or lack service role privileges. |
| Non-numeric column stored as metric | Ensure optional metrics are numeric values or leave the cell blank. |

## 7. Dry Run Example

```bash
python scripts/leaderboard/ingest_leaderboard_data.py \
  --csv data/leaderboard/business_overall.csv \
  --travel-class "Business" \
  --dry-run
```

This validates headers and airline mappings without touching Supabase.

## 8. Keeping Historical Snapshots

Each ingestion run creates a snapshot row. Historical snapshots remain in the database (with `is_active = false`), so you can build comparisons later or expose a history view without re-uploading.

---

Once your CSV matches the schema above, the leaderboard screens consume the data with no further Flutter changes.-

