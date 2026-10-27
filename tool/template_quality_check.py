#!/usr/bin/env python3
"""Audit the published Dart catalog and assets, without generated previews."""
from __future__ import annotations

import re
import sys

from published_catalog_source import ROOT, published_entries, source_assets


def main() -> int:
    try:
        entries, sources = published_entries()
        assets = source_assets(sources)
    except (OSError, ValueError, KeyError, StopIteration) as error:
        print(f"template_quality_check: cannot read runtime catalog: {error}")
        return 2
    issues = []
    for group, expected in (("free", 42), ("paid", 26)):
        actual = sum(entry.group == group for entry in entries)
        if actual != expected:
            issues.append(f"{group} catalog: expected {expected} identities, found {actual}")
    if len({entry.catalog_id for entry in entries}) != len(entries):
        issues.append("published catalog contains duplicate numeric IDs")
    if len({entry.slug for entry in entries}) != len(entries):
        issues.append("published catalog contains duplicate product identities")
    for entry in entries:
        if entry.catalog_id >= 0 or not re.fullmatch(r"[a-z0-9_-]+", entry.slug):
            issues.append(f"invalid published identity: {entry}")
    for path, source in sources.items():
        for forbidden in ("picsum.photos", "figma.com/api/mcp/asset/"):
            if forbidden in source:
                issues.append(f"{path.relative_to(ROOT)}: forbidden placeholder URL")
    for asset in sorted(assets):
        if not asset.is_file() or asset.stat().st_size == 0:
            issues.append(f"missing/empty authored asset: {asset.relative_to(ROOT)}")
    print("template_quality_check")
    print(f"source=published Dart catalog; templates={len(entries)}; static_assets={len(assets)}")
    print("runtime geometry, page counts and decoding remain checked by Flutter catalog tests")
    print(f"issues={len(issues)}")
    for issue in issues:
        print(f"- {issue}")
    return 2 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
