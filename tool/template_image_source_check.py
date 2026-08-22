#!/usr/bin/env python3
"""Validate Snapfit template image source tracking files.

This check does not prove that licenses are valid. It prevents the most common
mistake: treating reference-only sites as production image sources, and ensures
that every store template has a tracking file before templates are made store-grade.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
STORE = ROOT / "assets/templates/generated/store_latest.json"
LICENSE_DIR = ROOT / "assets/templates/_licenses"
FORBIDDEN_PRODUCTION_SOURCES = (
    "pinterest.",
    "pinimg.com",
    "miricanvas.com",
    "canva.com/templates",
    "instagram.com",
    "google.com/imgres",
    "googleusercontent.com",
)
ALLOWED_STATUS = {
    "approved-owned",
    "approved-paid-stock",
    "approved-free-stock",
    "approved-ai-generated",
    "needs-replacement",
    "reference-only",
}


def slug_for_template(template_id: str) -> str:
    return re.sub(r"_v\d+$", "", template_id.strip())


def main() -> int:
    issues: list[str] = []
    if not STORE.exists():
        print(f"missing {STORE.relative_to(ROOT)}")
        return 2
    rows = json.loads(STORE.read_text())
    if not isinstance(rows, list):
        print("store_latest must be a list")
        return 2
    for row in rows:
        if not isinstance(row, dict):
            continue
        template_id = str(row.get("templateId") or "").strip()
        if not template_id:
            continue
        slug = slug_for_template(template_id)
        source_file = LICENSE_DIR / f"{slug}_sources.md"
        if not source_file.exists():
            issues.append(f"{template_id}: missing image source file {source_file.relative_to(ROOT)}")
            continue
        text = source_file.read_text().lower()
        if "production status:" not in text:
            issues.append(f"{template_id}: source file missing Production status")
        found_statuses = {status for status in ALLOWED_STATUS if status in text}
        if not found_statuses:
            issues.append(f"{template_id}: source file has no recognized status label")
        for forbidden in FORBIDDEN_PRODUCTION_SOURCES:
            if forbidden in text and "reference-only" not in text:
                issues.append(
                    f"{template_id}: forbidden source appears without reference-only label: {forbidden}"
                )
    print("template_image_source_check")
    print(f"templates={len(rows)}")
    print(f"source_files={len(list(LICENSE_DIR.glob('*_sources.md'))) if LICENSE_DIR.exists() else 0}")
    print(f"issues={len(issues)}")
    for issue in issues:
        print(f"- {issue}")
    return 2 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
