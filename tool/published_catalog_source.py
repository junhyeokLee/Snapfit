"""Read identities/assets from the published Dart catalog, without JSON dumps.

This source audit fails on unknown declaration shapes. Flutter catalog tests
continue to cover runtime document geometry, page counts and image decoding.
"""
from __future__ import annotations

import ast
from dataclasses import dataclass
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = ROOT / "lib/core/templates"


@dataclass(frozen=True)
class CatalogEntry:
    slug: str
    catalog_id: int
    group: str


def _balanced(source: str, start: int) -> tuple[str, int]:
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = [pairs[source[start]]]
    quote = None
    escaped = False
    for index in range(start + 1, len(source)):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in "'\"":
            quote = char
        elif char in pairs:
            stack.append(pairs[char])
        elif char in ")]}":
            if not stack or char != stack.pop():
                raise ValueError("unbalanced catalog declaration")
            if not stack:
                return source[start + 1:index], index + 1
    raise ValueError("unterminated catalog declaration")


def _arguments(source: str) -> list[str]:
    result = []
    start = index = 0
    while index < len(source):
        char = source[index]
        if char in "([{":
            _, index = _balanced(source, index)
            continue
        if char in "'\"":
            quote = char
            index += 1
            while index < len(source):
                if source[index] == "\\":
                    index += 2
                elif source[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
            continue
        if char == ",":
            result.append(source[start:index].strip())
            start = index + 1
        index += 1
    if source[start:].strip():
        result.append(source[start:].strip())
    return result


def _enum(source: str, name: str) -> dict[str, list[str]]:
    body, _ = _balanced(source, source.index("{", source.index(f"enum {name}")))
    result = {}
    for entry in _arguments(body.split(";", 1)[0]):
        match = re.fullmatch(r"(\w+)\s*\((.*)\)", entry, re.S)
        if not match:
            raise ValueError(f"unsupported {name} value: {entry[:70]}")
        result[match[1]] = _arguments(match[2])
    return result


def catalog_sources() -> dict[Path, str]:
    main = TEMPLATES / "authored_collections.dart"
    source = main.read_text()
    paths = [main, TEMPLATES / "published_premium_templates.dart"]
    paths += [TEMPLATES / part for part in re.findall(r"part '([^']+)';", source)]
    return {path: path.read_text() for path in paths}


def published_entries() -> tuple[list[CatalogEntry], dict[Path, str]]:
    sources = catalog_sources()
    constants = {}
    for match in re.finditer(
        r"\bconst\s+(?:(?:String|int)\s+)?(\w+)\s*=\s*"
        r"('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|-?\d+)\s*;",
        "\n".join(sources.values()),
    ):
        constants[match[1]] = ast.literal_eval(match[2])

    def value(expression: str):
        expression = expression.strip()
        if expression in constants:
            return constants[expression]
        try:
            return ast.literal_eval(expression)
        except (ValueError, SyntaxError) as error:
            raise ValueError(f"unsupported catalog identity: {expression}") from error

    main = sources[TEMPLATES / "authored_collections.dart"]
    entries = []
    for name in ("baselineAuthoredCollections", "authoredCollections"):
        block, _ = _balanced(main, main.index("[", main.index(f"{name} =")))
        for match in re.finditer(r"\bAuthoredCollection\s*\(", block):
            call, _ = _balanced(block, match.end() - 1)
            args = _arguments(call)
            if args[0] == "volume.id":
                continue  # Expanded from FreeCollectionVolume below.
            named = next(arg for arg in args if arg.startswith("bundledId:"))
            entries.append(CatalogEntry(value(args[0]), value(named.split(":", 1)[1]), "free"))
    free = _enum(sources[TEMPLATES / "authored_free_expansion.dart"], "FreeCollectionVolume")
    entries += [CatalogEntry(value(args[0]), value(args[-1]), "free") for args in free.values()]

    identities = sources[TEMPLATES / "published_premium_templates.dart"]
    for enum_name, filename, map_name in (
        ("PremiumVolume", "authored_premium_volumes.dart", "premiumVolumeCatalogIds"),
        ("ConceptVolume", "authored_concept_wave.dart", "conceptVolumeCatalogIds"),
    ):
        enum_values = _enum(sources[TEMPLATES / filename], enum_name)
        block, _ = _balanced(identities, identities.index("{", identities.index(f"{map_name} =")))
        pairs = re.findall(rf"{enum_name}\.(\w+)\s*:\s*(-?\d+)", block)
        if set(name for name, _ in pairs) != set(enum_values):
            raise ValueError(f"{enum_name}: catalog map does not cover its values")
        entries += [CatalogEntry(value(enum_values[name][0]), int(catalog_id), "paid") for name, catalog_id in pairs]
    atelier = _enum(sources[TEMPLATES / "authored_atelier_editions.dart"], "AtelierEdition")
    entries += [CatalogEntry(value(args[0]), value(args[1]), "paid") for args in atelier.values()]
    studio = _enum(sources[TEMPLATES / "authored_studio_editions.dart"], "StudioEdition")
    entries += [CatalogEntry(value(args[0]), value(args[1]), "paid") for args in studio.values() if args[-1] == "true"]

    bundled = ROOT / "lib/features/album/data/bundled_creation_templates.dart"
    source = bundled.read_text()
    for required in ("authoredCollections", "premiumVolumeCatalogIds.entries", "conceptVolumeCatalogIds.entries", "AtelierEdition.values", "StudioEdition.values.where((e) => e.premium)"):
        if required not in source:
            raise ValueError(f"runtime catalog wiring changed: {required}")
    sources[bundled] = source
    return entries, sources


def source_assets(sources: dict[Path, str]) -> set[Path]:
    """Resolve literal images, local constant prefixes and edition cover paths."""
    assets = set()
    prefixes = dict(re.findall(
        r"(?:const|final)\s+(\w+)\s*=\s*'(assets/[^'$]+/)'",
        "\n".join(sources.values()),
    ))
    for source in sources.values():
        for literal in re.findall(r"'(?:\\.|[^'\\])*'", source):
            raw = literal[1:-1]
            for name, prefix in prefixes.items():
                raw = raw.replace("${" + name + "}", prefix)
            if raw.startswith("asset:"):
                raw = raw[6:]
            if raw.startswith("assets/") and "$" not in raw and re.search(r"\.(?:png|jpe?g|webp|avif)$", raw, re.I):
                assets.add(ROOT / raw)
    entries, _ = published_entries()
    for entry in entries:
        if (entry.group == "paid" and entry.catalog_id <= -9521) or entry.slug in {
            "alley-afternoon", "saturday-together", "daily-paw-walk", "our-first-promise", "little-day-discoveries"
        }:
            assets.add(ROOT / f"assets/templates/atelier_editions_2026/{entry.slug}.png")
    return assets
