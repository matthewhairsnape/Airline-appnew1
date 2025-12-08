#!/usr/bin/env python3
"""
Ingest leaderboard CSV data into Supabase.

Expected CSV headers (case-insensitive):
  - airline_iata (required)        : Airline IATA code used to resolve airline_id
  - category (required)            : Matches the Flutter tab labels (e.g. 'Wi-Fi Experience')
  - leaderboard_rank (optional)    : Integer rank (1-based). Calculated if absent.
  - leaderboard_score (required)   : Numeric score displayed in UI (0-100 or 0-5 scale)
  - travel_class (optional)        : Travel class for the row (Business, Economy, etc.)
  - avg_rating (optional)          : Average rating value (0-5)
  - review_count (optional)        : Integer count of surveys underpinning the row
  - positive_count (optional)      : Number of positive responses
  - negative_count (optional)      : Number of negative responses
  - positive_ratio (optional)      : Percentage positive (0-100)
  - Any additional numeric columns are persisted as metric breakdowns.

Usage:
  python scripts/leaderboard/ingest_leaderboard_data.py \
    --csv path/to/leaderboard.csv \
    --label "Nov 2025 Upload" \
    --travel-class Business \
    --reporting-start 2025-10-01 \
    --reporting-end 2025-10-31

Requirements:
  - Environment variables SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.
  - `requests` package installed (`python -m pip install requests python-dateutil`).
"""

import argparse
import csv
import os
import sys
from collections import defaultdict
from datetime import datetime
from decimal import Decimal, InvalidOperation
from typing import Any, Dict, List, Optional, Sequence, Tuple

import requests
from dateutil.parser import parse as parse_date

SUPABASE_REQUIRED_ENV = ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")

DEFAULT_NUMERIC_FIELDS = {
    "leaderboard_rank",
    "leaderboard_score",
    "avg_rating",
    "review_count",
    "positive_count",
    "negative_count",
    "positive_ratio",
}

BASE_HEADERS = {"Content-Type": "application/json"}


class IngestError(Exception):
    """Custom exception for ingestion failures."""


def _env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise IngestError(f"Environment variable {name} is required.")
    return value


def _decimal_or_none(raw: Any) -> Optional[Decimal]:
    if raw is None:
        return None
    if isinstance(raw, (int, float, Decimal)):
        return Decimal(str(raw))
    text = str(raw).strip()
    if not text:
        return None
    # Handle trailing '%' or other non-numeric characters gracefully
    sanitized = text.replace("%", "").replace(",", "")
    try:
        return Decimal(sanitized)
    except InvalidOperation:
        return None


def _int_or_none(raw: Any) -> Optional[int]:
    if raw is None:
        return None
    if isinstance(raw, int):
        return raw
    text = str(raw).strip()
    if not text:
        return None
    try:
        return int(float(text))
    except ValueError:
        return None


def _normalize_header(header: str) -> str:
    return header.strip().lower().replace(" ", "_")


def _detect_metric_columns(headers: Sequence[str]) -> List[str]:
    metrics = []
    for header in headers:
        normalized = _normalize_header(header)
        if normalized in ("airline_iata", "category", "travel_class"):
            continue
        if normalized in DEFAULT_NUMERIC_FIELDS:
            continue
        metrics.append(normalized)
    return metrics


def load_csv(path: str) -> Tuple[List[Dict[str, Any]], List[str]]:
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None:
            raise IngestError("CSV file has no header row.")
        normalized_fieldnames = [_normalize_header(name) for name in reader.fieldnames]
        rows: List[Dict[str, Any]] = []
        for raw_row in reader:
            normalized_row: Dict[str, Any] = {}
            for key, value in raw_row.items():
                normalized_row[_normalize_header(key)] = value.strip() if isinstance(value, str) else value
            rows.append(normalized_row)
    return rows, normalized_fieldnames


def fetch_airlines(client: "SupabaseRestClient", codes: Sequence[str]) -> Dict[str, Dict[str, Any]]:
    lookup: Dict[str, Dict[str, Any]] = {}
    for code in sorted(set(code.upper() for code in codes if code)):
        response = client.get(
            "/rest/v1/airlines",
            params={"select": "id,name,iata_code,icao_code", "iata_code": f"eq.{code}"},
        )
        data = response.json()
        if not data:
            raise IngestError(f"Airline with IATA code '{code}' not found in Supabase 'airlines' table.")
        lookup[code] = data[0]
    return lookup


class SupabaseRestClient:
    def __init__(self, url: str, api_key: str):
        self.base_url = url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update(
            {
                "apikey": api_key,
                "Authorization": f"Bearer {api_key}",
                **BASE_HEADERS,
            }
        )

    def request(self, method: str, path: str, **kwargs) -> requests.Response:
        url = f"{self.base_url}{path}"
        response = self.session.request(method, url, **kwargs)
        if response.status_code >= 400:
            raise IngestError(f"Supabase request failed ({response.status_code}): {response.text}")
        return response

    def get(self, path: str, **kwargs) -> requests.Response:
        return self.request("GET", path, **kwargs)

    def post(self, path: str, **kwargs) -> requests.Response:
        return self.request("POST", path, **kwargs)

    def delete(self, path: str, **kwargs) -> requests.Response:
        return self.request("DELETE", path, **kwargs)


def create_snapshot(
    client: SupabaseRestClient,
    label: str,
    travel_class: str,
    reporting_start: Optional[str],
    reporting_end: Optional[str],
    notes: Optional[str],
    source: str = "manual_upload",
) -> Dict[str, Any]:
    payload = {
        "label": label,
        "travel_class": travel_class,
        "source": source,
    }
    if reporting_start:
        payload["reporting_period_start"] = reporting_start
    if reporting_end:
        payload["reporting_period_end"] = reporting_end
    if notes:
        payload["notes"] = notes

    response = client.post(
        "/rest/v1/leaderboard_snapshots",
        json=payload,
        params={"select": "id,label,travel_class"},
    )
    data = response.json()
    if isinstance(data, list):
        return data[0]
    return data


def insert_rankings_and_metrics(
    client: SupabaseRestClient,
    snapshot_id: str,
    travel_class: str,
    rows: Sequence[Dict[str, Any]],
    airline_lookup: Dict[str, Dict[str, Any]],
    metric_columns: Sequence[str],
) -> None:
    ranking_payload: List[Dict[str, Any]] = []
    metrics_payload: List[Dict[str, Any]] = []

    auto_rank_counters: Dict[str, int] = defaultdict(int)

    for row in rows:
        iata = row.get("airline_iata")
        category = row.get("category")
        if not iata or not category:
            raise IngestError("Each row must contain 'airline_iata' and 'category' columns.")

        airline_info = airline_lookup.get(iata.upper())
        if not airline_info:
            raise IngestError(f"No airline mapping found for IATA code '{iata}'.")

        leaderboard_score = _decimal_or_none(row.get("leaderboard_score"))
        if leaderboard_score is None:
            raise IngestError(f"Row for airline {iata} / category {category} is missing 'leaderboard_score'.")

        leaderboard_rank = _int_or_none(row.get("leaderboard_rank"))
        if leaderboard_rank is None:
            auto_rank_counters[category] += 1
            leaderboard_rank = auto_rank_counters[category]

        avg_rating = _decimal_or_none(row.get("avg_rating"))
        review_count = _int_or_none(row.get("review_count"))
        positive_count = _int_or_none(row.get("positive_count"))
        negative_count = _int_or_none(row.get("negative_count"))
        positive_ratio = _decimal_or_none(row.get("positive_ratio"))

        ranking_payload.append(
            {
                "snapshot_id": snapshot_id,
                "airline_id": airline_info["id"],
                "category": category,
                "travel_class": row.get("travel_class") or travel_class,
                "leaderboard_rank": leaderboard_rank,
                "leaderboard_score": float(leaderboard_score),
                "avg_rating": float(avg_rating) if avg_rating is not None else None,
                "review_count": review_count,
                "positive_count": positive_count,
                "negative_count": negative_count,
                "positive_ratio": float(positive_ratio) if positive_ratio is not None else None,
                "is_active": False,
            }
        )

    if ranking_payload:
        client.post(
            "/rest/v1/leaderboard_rankings",
            json=ranking_payload,
            params={"select": "id,airline_id,category"},
            headers={"Prefer": "return=representation"},
        )

    # Fetch inserted ranking IDs for metric linkage
    ranking_lookup_response = client.get(
        "/rest/v1/leaderboard_rankings",
        params={
            "snapshot_id": f"eq.{snapshot_id}",
            "select": "id,airline_id,category,travel_class",
        },
    )
    ranking_lookup = ranking_lookup_response.json()
    ranking_index: Dict[Tuple[str, str], str] = {}
    for item in ranking_lookup:
        ranking_index[(item["airline_id"], item["category"])] = item["id"]

    for row in rows:
        airline_id = airline_lookup[row["airline_iata"].upper()]["id"]
        ranking_id = ranking_index.get((airline_id, row["category"]))
        if not ranking_id:
            raise IngestError(
                f"Failed to resolve ranking_id for airline {row['airline_iata']} / category {row['category']}."
            )

        for metric_col in metric_columns:
            if metric_col in DEFAULT_NUMERIC_FIELDS:
                continue
            value = row.get(metric_col)
            numeric_value = _decimal_or_none(value)
            if numeric_value is None:
                continue
            metrics_payload.append(
                {
                    "ranking_id": ranking_id,
                    "metric_key": metric_col,
                    "metric_value": float(numeric_value),
                }
            )

    if metrics_payload:
        client.post(
            "/rest/v1/leaderboard_metrics",
            json=metrics_payload,
            headers={"Prefer": "return=minimal"},
        )


def activate_snapshot(client: SupabaseRestClient, snapshot_id: str) -> None:
    client.post(
        "/rest/v1/rpc/activate_leaderboard_snapshot",
        json={"p_snapshot_id": snapshot_id},
    )


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Ingest leaderboard CSV into Supabase.")
    parser.add_argument("--csv", dest="csv_path", required=True, help="Path to the leaderboard CSV file.")
    parser.add_argument("--label", required=False, help="Snapshot label. Defaults to derived timestamp label.")
    parser.add_argument("--travel-class", dest="travel_class", required=False, help="Travel class (e.g. Business).")
    parser.add_argument("--reporting-start", dest="reporting_start", help="Reporting period start date (YYYY-MM-DD).")
    parser.add_argument("--reporting-end", dest="reporting_end", help="Reporting period end date (YYYY-MM-DD).")
    parser.add_argument("--notes", help="Optional notes stored on the snapshot.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse CSV and resolve airlines but do not push to Supabase.",
    )
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)

    for env_var in SUPABASE_REQUIRED_ENV:
        _env(env_var)

    rows, headers = load_csv(args.csv_path)
    if not rows:
        raise IngestError("CSV contains no data rows.")

    travel_class = args.travel_class or rows[0].get("travel_class")
    if not travel_class:
        raise IngestError("Travel class must be provided via --travel-class or in the CSV.")

    airline_codes = [row.get("airline_iata", "").upper() for row in rows]
    if any(not code for code in airline_codes):
        raise IngestError("All rows must include 'airline_iata'.")

    metric_columns = _detect_metric_columns(headers)

    client = SupabaseRestClient(_env("SUPABASE_URL"), _env("SUPABASE_SERVICE_ROLE_KEY"))

    airline_lookup = fetch_airlines(client, airline_codes)

    if args.dry_run:
        print("✅ Dry run completed. Parsed rows:")
        for row in rows:
            print(f"  - {row.get('airline_iata')} / {row.get('category')} -> score {row.get('leaderboard_score')}")
        print(f"Detected metric columns: {metric_columns}")
        return 0

    snapshot_label = (
        args.label
        or f"{travel_class} upload {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')}"
    )

    reporting_start = args.reporting_start
    reporting_end = args.reporting_end

    # Validate date formats if provided
    for date_label, value in (("reporting_start", reporting_start), ("reporting_end", reporting_end)):
        if value:
            try:
                parse_date(value).date()
            except (ValueError, TypeError):
                raise IngestError(f"Invalid date format for --{date_label}: {value}")

    snapshot = create_snapshot(
        client,
        label=snapshot_label,
        travel_class=travel_class,
        reporting_start=reporting_start,
        reporting_end=reporting_end,
        notes=args.notes,
    )

    insert_rankings_and_metrics(
        client=client,
        snapshot_id=snapshot["id"],
        travel_class=travel_class,
        rows=rows,
        airline_lookup=airline_lookup,
        metric_columns=metric_columns,
    )

    activate_snapshot(client, snapshot["id"])

    print("✅ Leaderboard ingestion completed successfully.")
    print(f"Snapshot '{snapshot_label}' ({snapshot['id']}) activated for travel class {travel_class}.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except IngestError as exc:
        sys.stderr.write(f"❌ {exc}\n")
        sys.exit(1)

