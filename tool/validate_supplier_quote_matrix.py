#!/usr/bin/env python3
"""Validate the reviewed PHBKMYB website capture and export PRIVATE seed/CSV files.

This is a local, standard-library-only tool. It never calls a provider or database.
It requires every one-copy combination (5 sizes x 2 covers x 31 even page counts)
before writing anything. These files contain procurement costs: do not publish them.

The capture session's manually reviewed fixed options are recorded below. Only the
initial 8X8 SOFT batch may use that shared review instead of per-row uiOptions.
Other rows must corroborate their stock, duplex mode, size and sheet count with
the actual selected UI options. Cover type and matte finish were reviewed through
the controls outside that selected-option list; they are not inferred from price.

Prices exported here are PLANNED contribution estimates, not FINAL prices or net
profit. Generating/applying the SQL never enables payment or production ordering.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from typing import Any


PRODUCT_URL = "https://www.redprinting.co.kr/ko/product/item/PH/PHBKMYB"
OPTION_CONTRACT = "PHBKMYB_GLOSSY285_MATTE_DUPLEX_V1"
# Explicit human review in the 2026-10-19 official website collection session.
# uiOptions omits the cover-type and matte-finish controls for every batch.
SHARED_OPTION_EVIDENCE = (
    "Official PHBKMYB website collection reviewed on 2026-10-19 KST: "
    "Glossy Canon 285g duplex interior; SOFT Art 300g / HARD Snow 180g cover; "
    "single-sided matte cover coating. The initial 8X8 SOFT 20-80-page batch "
    "was explicitly reviewed with these same fixed options before collection."
)
SIZES = {
    "8X6": ("200X150", 200, 150, "1"),
    "8X8": ("200", 200, 200, "2"),
    "10X8": ("250X200", 250, 200, "3"),
    "10X10": ("250", 250, 250, "4"),
    "12X12": ("300", 300, 300, "5"),
}
COVERS = ("SOFT", "HARD")
PAGES = range(20, 81, 2)
EXPECTED = {(size, cover, pages) for size in SIZES for cover in COVERS for pages in PAGES}
SHIPPING_BUDGET = 3500
OPERATIONS_BUDGET = 3000
MAX_COST = 100_000_000


class ValidationError(ValueError):
    """An incomplete or uncorroborated capture must not produce a seed."""


def fail(message: str) -> None:
    raise ValidationError(message)


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"Duplicate JSON property: {key!r}")
        result[key] = value
    return result


def integer(row: dict[str, Any], field: str, context: str) -> int:
    value = row.get(field)
    if type(value) is not int:  # bool and numeric strings are not a captured price.
        fail(f"{context}: {field} must be a JSON integer, got {value!r}")
    return value


def ceil_div(value: int, divisor: int) -> int:
    return (value + divisor - 1) // divisor


def planned_budget(print_cost: int, cover: str) -> dict[str, int]:
    """Mirror private.print_quote_retail_budget using only integer arithmetic."""
    packaging = 1500 if cover == "HARD" else 0
    fixed = print_cost + SHIPPING_BUDGET + packaging + OPERATIONS_BUDGET
    lower_bound = max(ceil_div((fixed + 10000) * 10, 9), ceil_div(fixed * 10, 7))
    retail = max(9900, ceil_div(lower_bound + 100, 10000) * 10000 - 100)
    while True:
        fee = ceil_div(retail, 20)
        reprint = ceil_div(retail, 20)
        contribution = retail - fixed - fee - reprint
        if contribution >= 10000 and contribution * 5 >= retail:
            break
        retail += 10000
    # Guard the exported policy itself, including the smallest permissible tier.
    prior = retail - 10000
    prior_contribution = prior - fixed - 2 * ceil_div(prior, 20)
    if retail % 10000 != 9900 or (
        prior >= 9900 and prior_contribution >= 10000 and prior_contribution * 5 >= prior
    ):
        fail("Internal pricing error: retail is not the smallest qualifying 9,900 tier")
    return {
        "shipping_budget": SHIPPING_BUDGET,
        "packaging_budget": packaging,
        "operations_budget": OPERATIONS_BUDGET,
        "planned_retail": retail,
        "payment_fee_budget": fee,
        "reprint_budget": reprint,
        "estimated_contribution": contribution,
    }


def validate_options(row: dict[str, Any], context: str) -> str:
    if "uiOptions" not in row:
        if row["size"] == "8X8" and row["cover"] == "SOFT":
            return "SHARED_REVIEW_INITIAL_8X8_SOFT_BATCH"
        fail(f"{context}: missing uiOptions; shared review is limited to the initial 8X8 SOFT batch")
    selected = row["uiOptions"]
    if not isinstance(selected, list) or len(selected) != 9:
        fail(f"{context}: uiOptions must contain exactly the 9 captured selected options")
    actual: list[tuple[str, str, str]] = []
    for option in selected:
        if not isinstance(option, dict) or set(option) != {"name", "label", "value"}:
            fail(f"{context}: each uiOption must have name, label and value only")
        if any(not isinstance(option[k], str) or not option[k].strip() for k in option):
            fail(f"{context}: uiOption names, labels and values must be nonempty strings")
        actual.append((option["name"], option["label"], option["value"]))
    soft = row["cover"] == "SOFT"
    expected = [
        ("sizes", row["size"], SIZES[row["size"]][3]),
        ("QTY", "1", "1"),
        ("dosu", "양면", "SID_D"),
        ("paper", "유광(Glossy)_캐논전용지", "DGP"),
        ("weight", "285g", "RXDGP285"),
        ("INNER_QTY", str(row["pageCount"] // 2), str(row["pageCount"] // 2)),
        ("dosu", "단면", "SID_S"),
        ("paper", "아트지" if soft else "스노우", "ART" if soft else "SNO"),
        ("weight", "300g" if soft else "180g", "RXART300" if soft else "RXSNO180"),
    ]
    # DOM order is irrelevant, but duplicates, unexpected selections and mismatches
    # are not. Sorting keeps the two distinct paper/dosu controls distinguishable.
    if sorted(actual) != sorted(expected):
        missing = sorted(set(expected) - set(actual))
        unexpected = sorted(set(actual) - set(expected))
        fail(f"{context}: uiOptions mismatch; missing={missing!r}; unexpected={unexpected!r}")
    return "ROW_UI_OPTIONS_PLUS_SHARED_COVER_FINISH_REVIEW"


def validate_capture(raw: bytes, now: datetime) -> list[dict[str, Any]]:
    try:
        data = json.loads(raw.decode("utf-8-sig"), object_pairs_hook=unique_object)
    except (UnicodeError, json.JSONDecodeError) as error:
        fail(f"Input is not complete UTF-8 JSON (capture may still be updating): {error}")
    if not isinstance(data, list):
        fail("Input must be the raw supplier-ui-quotes.json array")
    if len(data) != len(EXPECTED):
        fail(f"Incomplete matrix: expected exactly 310 rows, found {len(data)}. Finish collection before exporting.")
    digest = hashlib.sha256(raw).hexdigest()
    seen: set[tuple[str, str, int]] = set()
    validated: list[dict[str, Any]] = []
    for index, row in enumerate(data, 1):
        context = f"Row {index}"
        if not isinstance(row, dict):
            fail(f"{context}: expected an object")
        if not isinstance(row.get("size"), str) or not isinstance(row.get("cover"), str) or row["size"] not in SIZES or row["cover"] not in COVERS:
            fail(f"{context}: unsupported size/cover {row.get('size')!r}/{row.get('cover')!r}")
        pages = integer(row, "pageCount", context)
        key = (row["size"], row["cover"], pages)
        context = f"{context} {key[0]}/{key[1]}/{pages}p"
        if key not in EXPECTED:
            fail(f"{context}: pages must be even and between 20 and 80")
        if key in seen:
            fail(f"{context}: duplicate combination")
        seen.add(key)
        if integer(row, "quantity", context) != 1:
            fail(f"{context}: only quantity=1 is verified")
        supply, vat, total = (integer(row, name, context) for name in ("supplyPrice", "vatPrice", "totalPrice"))
        if not all(0 < price <= MAX_COST for price in (supply, vat, total)):
            fail(f"{context}: supply, VAT and total must be positive and <= {MAX_COST}")
        if supply + vat != total:
            fail(f"{context}: supplyPrice + vatPrice does not equal totalPrice")
        if vat * 10 != supply:
            fail(f"{context}: VAT does not match the captured 10% VAT contract")
        timestamp = row.get("observedAt")
        if not isinstance(timestamp, str) or not timestamp.strip():
            fail(f"{context}: observedAt is required")
        try:
            observed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        except ValueError:
            fail(f"{context}: observedAt must be an ISO8601 timestamp")
        if observed.tzinfo is None or observed.utcoffset() is None:
            fail(f"{context}: observedAt must include its time zone")
        observed = observed.astimezone(timezone.utc)
        if observed > now + timedelta(minutes=5):
            fail(f"{context}: observedAt is more than 5 minutes in the future")
        provenance = validate_options(row, context)
        soft = row["cover"] == "SOFT"
        product_id = f"REDP_{SIZES[row['size']][0]}_{row['cover']}"
        # Existing optional metadata may corroborate the capture, never contradict it.
        for name, expected in (("source", "WEBSITE"), ("confirmed", True), ("productId", product_id)):
            if name in row and (type(row[name]) is not type(expected) or row[name] != expected):
                fail(f"{context}: contradictory {name}={row[name]!r}")
        options = {
            "coverPaper": "아트지 300g" if soft else "스노우지 180g",
            "coverFinish": "단면 무광코팅",
            "interiorPaper": "Glossy Canon 285g",
            "interiorPrint": "양면",
            "optionContract": OPTION_CONTRACT,
            "optionEvidence": provenance,
        }
        if "uiOptions" in row:
            options["capturedUiOptions"] = row["uiOptions"]
        evidence = (
            f"Official website PHBKMYB one-copy UI quote: {PRODUCT_URL}; "
            f"size={row['size']}; cover={row['cover']}; interiorPages={pages}; qty=1; "
            f"optionEvidence={provenance}; {SHARED_OPTION_EVIDENCE} "
            f"rawCaptureSHA256={digest}; rawRow={index}."
        )
        if not 10 <= len(evidence.strip()) <= 5000:
            fail(f"{context}: evidence does not satisfy the database contract")
        validated.append({
            "product_id": product_id, "size": row["size"], "cover": row["cover"],
            "trim_width_mm": SIZES[row["size"]][1], "trim_height_mm": SIZES[row["size"]][2],
            "page_count": pages, "quantity": 1, "currency": "KRW",
            "supply_price": supply, "vat_price": vat, "total_price": total,
            "source": "WEBSITE", "confirmed": True,
            "observed_at": observed.isoformat().replace("+00:00", "Z"),
            "evidence": evidence, "options": options, "option_evidence": provenance,
            **planned_budget(total, row["cover"]),
        })
    missing = EXPECTED - seen
    if missing:
        fail(f"Incomplete matrix: missing combinations {sorted(missing)!r}")
    validated.sort(key=lambda row: (list(SIZES).index(row["size"]), COVERS.index(row["cover"]), row["page_count"]))
    for size in SIZES:
        for cover in COVERS:
            group = [row for row in validated if row["size"] == size and row["cover"] == cover]
            for before, after in zip(group, group[1:]):
                if after["total_price"] < before["total_price"] or after["planned_retail"] < before["planned_retail"]:
                    fail(f"Nonmonotone price needs review: {size}/{cover} {before['page_count']}p -> {after['page_count']}p")
    return validated


def sql_string(value: str) -> str:
    if "\x00" in value:
        fail("NUL cannot be represented in a PostgreSQL string")
    return "'" + value.replace("'", "''") + "'"


def seed_sql(rows: list[dict[str, Any]], digest: str) -> str:
    values = []
    for row in rows:
        values.append("  (" + ",".join([
            sql_string(row["product_id"]), str(row["page_count"]),
            str(row["supply_price"]), str(row["vat_price"]), str(row["total_price"]),
            sql_string(row["observed_at"]) + "::timestamptz",
            sql_string(row["option_evidence"]),
        ]) + ")")
    evidence_prefix = (
        f"Official website PHBKMYB one-copy UI quote: {PRODUCT_URL}; "
        f"rawCaptureSHA256={digest}; {SHARED_OPTION_EVIDENCE} rowKey="
    )
    return (
        "-- PRIVATE procurement evidence. Do not publish this file or raw cost rows.\n"
        f"-- Complete verified WEBSITE matrix: 310 combinations; input SHA256 {digest}.\n"
        "-- Schema: 20261018174925_redprinting_supplier_quote_retail_matrix.sql.\n"
        "-- Newer supplier observations win. No financial/operational approval or payment flags are changed.\n"
        "-- No BEGIN/COMMIT: the migration executor owns the transaction.\n"
        "with captured(product_id,page_count,supply_price,vat_price,total_price,observed_at,option_evidence) as (\n"
        "  values\n" + ",\n".join(values) + "\n)\n"
        "insert into private.print_supplier_quotes as current_quote\n"
        "  (product_id,page_count,quantity,currency,supply_price,vat_price,total_price,source,observed_at,evidence,options,confirmed)\n"
        "select q.product_id,q.page_count,1,'KRW',q.supply_price,q.vat_price,q.total_price,'WEBSITE',q.observed_at,\n"
        f"  {sql_string(evidence_prefix)}||q.product_id||':'||q.page_count::text||':qty1; optionEvidence='||q.option_evidence,\n"
        "  jsonb_build_object('coverPaper',case when right(q.product_id,5)='_HARD' then '스노우지 180g' else '아트지 300g' end,\n"
        "    'coverFinish','단면 무광코팅','interiorPaper','Glossy Canon 285g','interiorPrint','양면',\n"
        f"    'optionContract',{sql_string(OPTION_CONTRACT)},'optionEvidence',q.option_evidence),true\n"
        "from captured q where true\n"
        "on conflict(product_id,page_count,quantity) do update set\n"
        "  currency=excluded.currency,supply_price=excluded.supply_price,vat_price=excluded.vat_price,total_price=excluded.total_price,\n"
        "  source=excluded.source,observed_at=excluded.observed_at,evidence=excluded.evidence,options=excluded.options,confirmed=true\n"
        "where current_quote.observed_at<excluded.observed_at;\n"
    )


def matrix_csv(rows: list[dict[str, Any]]) -> str:
    output = io.StringIO(newline="")
    fields = [
        "product_id", "size", "cover", "trim_width_mm", "trim_height_mm", "page_count", "quantity", "currency",
        "supply_price", "vat_price", "total_price", "source", "confirmed", "observed_at", "option_evidence",
        "shipping_budget", "packaging_budget", "operations_budget", "payment_fee_budget", "reprint_budget",
        "planned_retail", "estimated_contribution", "contribution_percent", "retail_status",
        "pg_rate_is_assumption", "shipping_is_budget", "packaging_is_budget", "margin_definition", "evidence", "options_json",
    ]
    writer = csv.DictWriter(output, fieldnames=fields)
    writer.writeheader()
    for row in rows:
        item = {field: row[field] for field in fields if field in row}
        # Display only: exact margin tests above use integer cross multiplication.
        percent_hundredths = row["estimated_contribution"] * 10000 // row["planned_retail"]
        item.update({
            "confirmed": "true", "contribution_percent": f"{percent_hundredths // 100}.{percent_hundredths % 100:02}",
            "retail_status": "PLANNED", "pg_rate_is_assumption": "true", "shipping_is_budget": "true", "packaging_is_budget": "true",
            "margin_definition": "Estimated contribution before taxes, remaining labor, fixed overhead and advertising; not net profit",
            "options_json": json.dumps(row["options"], ensure_ascii=False, separators=(",", ":")),
        })
        writer.writerow(item)
    return output.getvalue()


def write_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary: str | None = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="", dir=path.parent, prefix=f".{path.name}.", delete=False) as output:
            temporary = output.name
            output.write(content)
        os.replace(temporary, path)
    finally:
        if temporary is not None and os.path.exists(temporary):
            os.unlink(temporary)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", type=Path, required=True, help="Completed raw supplier-ui-quotes.json capture (310 rows)")
    parser.add_argument("--sql-output", type=Path, required=True, help="Private procurement seed SQL output")
    parser.add_argument("--csv-output", type=Path, required=True, help="Private cost/planned-retail/margin CSV output")
    args = parser.parse_args(argv)
    try:
        paths = [path.resolve() for path in (args.input, args.sql_output, args.csv_output)]
        if len(set(paths)) != 3:
            fail("Input, SQL output and CSV output must be three different files")
        raw = args.input.read_bytes()
        rows = validate_capture(raw, datetime.now(timezone.utc))
        # Finish every validation and serialization before creating either output.
        sql = seed_sql(rows, hashlib.sha256(raw).hexdigest())
        csv_text = matrix_csv(rows)
        write_atomic(args.sql_output, sql)
        write_atomic(args.csv_output, csv_text)
    except (ValidationError, OSError) as error:
        print(f"VALIDATION FAILED: {error}", file=sys.stderr)
        return 1
    print(f"Validated 310 exact one-copy WEBSITE quotes; wrote {args.sql_output} and {args.csv_output}.")
    print("All planned prices satisfy >=10,000 KRW and >=20% estimated contribution. Export only: does not enable payment or ordering.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
