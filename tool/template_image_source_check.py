#!/usr/bin/env python3
"""Check source tracking for images referenced by the current Dart catalog.

Tracking does not establish commercial rights or print approval. Pending review
remains pending; this check never upgrades a source's recorded approval status.
"""
from __future__ import annotations

import json
import re
import sys

from published_catalog_source import ROOT, published_entries, source_assets

FORBIDDEN_SOURCES = ("pinterest.", "pinimg.com", "miricanvas.com", "canva.com/templates", "instagram.com", "google.com/imgres", "googleusercontent.com")


def _records(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _records(child)
    elif isinstance(value, list):
        for child in value:
            yield from _records(child)


def main() -> int:
    issues = []
    tracked = set()
    pending_delivery = set()
    try:
        entries, sources = published_entries()
        assets = {path for path in source_assets(sources) if "assets/templates/" in path.as_posix()}
        for path in (ROOT / "assets/templates").rglob("*provenance*.json"):
            document = json.loads(path.read_text())
            for record in _records(document):
                for field in ("assetPath", "path", "file", "asset"):
                    raw = record.get(field)
                    if not isinstance(raw, str) or not re.search(r"\.(?:png|jpe?g|webp|avif)$", raw, re.I):
                        continue
                    if raw.startswith("assets/"):
                        candidates = [ROOT / raw]
                    else:
                        candidates = [path.parent / raw, path.parent / "images" / raw]
                    tracked.update(candidate.resolve() for candidate in candidates if candidate.is_file())
        for path in (ROOT / "assets/templates/_licenses").glob("*_sources.md"):
            text = path.read_text()
            if "production status:" not in text.lower():
                issues.append(f"{path.relative_to(ROOT)}: missing recorded production status")
            if any(host in text.lower() for host in FORBIDDEN_SOURCES) and "reference-only" not in text.lower():
                issues.append(f"{path.relative_to(ROOT)}: reference-only source lacks that label")
            for raw in re.findall(r"assets/[^\s|`]+\.(?:png|jpe?g|webp|avif)", text, re.I):
                if (ROOT / raw).is_file():
                    tracked.add((ROOT / raw).resolve())
        # The six replacement cover photographs have their individual prompts
        # in the reviewed art-direction document, rather than a JSON manifest.
        direction = ROOT / "docs/template_cover_art_direction.md"
        for line in direction.read_text().splitlines():
            match = re.match(r"\| `([^`]+\.(?:png|jpg))` \|[^|]+\| (.+) \|", line)
            if match and len(match[2]) > 40:
                candidate = ROOT / "assets/templates/original_editorial/images" / match[1]
                if candidate.is_file():
                    tracked.add(candidate.resolve())
        # Shared photographs from retired designs are still used by the live
        # catalog. Keep their existing delivery/source trace, explicitly pending
        # review. A CDN URL is not evidence of an approved commercial license.
        for manifest in (ROOT / "assets/templates").glob("*/cdn_manifest.json"):
            delivery = json.loads(manifest.read_text())
            source_note = ROOT / "assets/templates/_licenses" / f"{manifest.parent.name}_sources.md"
            if not source_note.is_file():
                continue
            names = {
                record["fileName"] for record in _records(delivery)
                if isinstance(record.get("fileName"), str)
            }
            for asset in assets:
                if manifest.parent in asset.parents and asset.name in names and asset.resolve() not in tracked:
                    tracked.add(asset.resolve())
                    pending_delivery.add(asset)
        for path in sorted(assets):
            if path.resolve() not in tracked:
                issues.append(f"image source tracking missing: {path.relative_to(ROOT)}")
    except (OSError, ValueError, KeyError, StopIteration) as error:
        print(f"template_image_source_check: cannot read catalog/provenance: {error}")
        return 2
    print("template_image_source_check")
    print(f"templates={len(entries)}; referenced_template_images={len(assets)}; tracked_images={len(tracked)}")
    print("source tracking only; existing rights/print review status is unchanged")
    print(f"legacy_delivery_traces_pending_review={len(pending_delivery)}")
    for path in sorted(pending_delivery):
        print(f"pending-source-review: {path.relative_to(ROOT)}")
    print(f"issues={len(issues)}")
    for issue in issues:
        print(f"- {issue}")
    return 2 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
