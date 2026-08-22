#!/usr/bin/env python3
"""Validate generated SnapFit store templates before publishing."""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
STORE = ROOT / "assets/templates/generated/store_latest.json"
FORBIDDEN_URL_PARTS = ("picsum.photos", "figma.com/api/mcp/asset/")


def text(value) -> str:
    return "" if value is None else str(value).strip()


def collect_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from collect_strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from collect_strings(v)


def asset_path(value: str) -> pathlib.Path | None:
    if not value.startswith("asset:"):
        return None
    rel = value[len("asset:"):]
    return ROOT / rel


def main() -> int:
    issues: list[str] = []
    if not STORE.exists():
        print(f"template_quality_check: missing {STORE.relative_to(ROOT)}")
        return 2
    try:
        rows = json.loads(STORE.read_text())
    except Exception as exc:
        print(f"template_quality_check: invalid JSON: {exc}")
        return 2
    if not isinstance(rows, list) or not rows:
        print("template_quality_check: store_latest must be a non-empty list")
        return 2

    seen_ids: set[str] = set()
    for idx, row in enumerate(rows):
        if not isinstance(row, dict):
            issues.append(f"row {idx}: not an object")
            continue
        label = text(row.get("templateId")) or text(row.get("title")) or f"row {idx}"
        template_id = text(row.get("templateId"))
        if not template_id:
            issues.append(f"{label}: missing templateId")
        elif template_id in seen_ids:
            issues.append(f"{label}: duplicate templateId")
        seen_ids.add(template_id)

        for field in ("title", "description", "category", "coverImageUrl"):
            if not text(row.get(field)):
                issues.append(f"{label}: missing {field}")
        previews = row.get("previewImages")
        if not isinstance(previews, list) or not previews:
            issues.append(f"{label}: previewImages must be a non-empty list")
            previews = []
        raw_template = row.get("templateJson")
        try:
            template = json.loads(raw_template) if isinstance(raw_template, str) else raw_template
        except Exception as exc:
            issues.append(f"{label}: invalid templateJson: {exc}")
            template = None
        if not isinstance(template, dict):
            issues.append(f"{label}: templateJson must decode to an object")
            continue
        pages = template.get("pages")
        if not isinstance(pages, list) or not pages:
            issues.append(f"{label}: templateJson.pages must be a non-empty list")
            pages = []
        page_count = row.get("pageCount")
        if page_count != len(pages):
            issues.append(f"{label}: pageCount={page_count} but templateJson.pages={len(pages)}")
        cover = template.get("cover")
        if not isinstance(cover, dict) or not isinstance(cover.get("layers"), list) or not cover.get("layers"):
            issues.append(f"{label}: cover.layers must be non-empty")

        all_strings = [text(row.get("coverImageUrl")), *map(text, previews), *collect_strings(template)]
        for value in all_strings:
            if any(part in value for part in FORBIDDEN_URL_PARTS):
                issues.append(f"{label}: forbidden placeholder URL: {value[:120]}")
            path = asset_path(value)
            if path is not None and not path.exists():
                issues.append(f"{label}: missing asset file: {path.relative_to(ROOT)}")

    print("template_quality_check")
    print(f"store={STORE.relative_to(ROOT)}")
    print(f"templates={len(rows)}")
    print(f"issues={len(issues)}")
    for issue in issues:
        print(f"- {issue}")
    return 2 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
