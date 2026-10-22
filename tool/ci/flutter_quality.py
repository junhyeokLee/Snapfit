#!/usr/bin/env python3
"""Shared CI/pre-push SDK pins and generated-source checks."""

import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
PINS_PATH = Path("tool/print_fulfillment/linux/runtime-pins.json")
GENERATED_PATHS = (":(glob)**/*.g.dart", ":(glob)**/*.freezed.dart")
CI_INPUT_PATHS = (
    ":(glob)lib/**/*.dart",
    "test", "integration_test", "assets", "packages", "tool", "scripts", "supabase",
    ".github", ".githooks", "docs", "web", "android", "ios", "linux",
    "macos", "windows", "Makefile", "pubspec.yaml", "pubspec.lock",
    "analysis_options.yaml", "build.yaml", "dart_test.yaml", "l10n.yaml",
    ".gitignore", ".metadata", ".fvmrc", "firebase.json", ".firebaserc",
)
NO_UPDATES_TO_CHECK = 10


def sdk_pins(root=ROOT):
    pins = json.loads((root / PINS_PATH).read_text(encoding="utf-8"))["flutter"]
    return pins["version"], pins["dartVersion"]


def verify_sdk(root=ROOT):
    expected_flutter, expected_dart = sdk_pins(root)
    flutter = subprocess.run(
        ["flutter", "--version", "--machine"],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    )
    machine = json.loads(flutter.stdout)
    actual_flutter = machine["frameworkVersion"]
    bundled_match = re.match(r"(\d+\.\d+\.\d+)\b", machine["dartSdkVersion"])
    bundled_dart = bundled_match.group(1) if bundled_match else "unknown"
    dart = subprocess.run(
        ["dart", "--version"], cwd=root, capture_output=True, text=True, check=True
    )
    match = re.search(r"Dart SDK version: (\d+\.\d+\.\d+)\b", dart.stdout + dart.stderr)
    actual_dart = match.group(1) if match else "unknown"
    if (actual_flutter, bundled_dart, actual_dart) != (
        expected_flutter, expected_dart, expected_dart
    ):
        print(
            f"Use Flutter {expected_flutter} with its Dart {expected_dart}. "
            f"Found Flutter {actual_flutter}, bundled Dart {bundled_dart}, "
            f"PATH Dart {actual_dart}.",
            file=sys.stderr,
        )
        return False
    return True


def verify_generated_files(root=ROOT):
    tracked = subprocess.run(
        ["git", "diff", "--name-status", "HEAD", "--", *GENERATED_PATHS],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard", "-z", "--", *GENERATED_PATHS],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split("\0")
    untracked = [path for path in untracked if path]
    # Generated sources cannot escape the check by accidentally being ignored.
    # Build/cache directories outside the source trees remain ordinary ignores.
    ignored_sources = subprocess.run(
        [
            "git", "ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--",
            ":(glob)lib/**/*.g.dart", ":(glob)lib/**/*.freezed.dart",
            ":(glob)test/**/*.g.dart", ":(glob)test/**/*.freezed.dart",
        ],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split("\0")
    untracked.extend(path for path in ignored_sources if path)
    if not tracked and not untracked:
        return True
    print("Generated Dart sources differ from the committed revision:", file=sys.stderr)
    if tracked:
        print(tracked.rstrip(), file=sys.stderr)
    for path in untracked:
        print(f"untracked\t{path}", file=sys.stderr)
    print("Regenerate, review and commit these generated sources before pushing.", file=sys.stderr)
    return False


def pre_push_status(root=ROOT, updates=""):
    """Check the pushed commit, not a locally repaired/uncommitted worktree.

    Status 10 means no non-deletion update needs the expensive SDK checks.
    This guard is hook-only; ordinary local quality checks allow design edits.
    """
    non_deletion_updates = []
    for line in updates.splitlines():
        if not line.strip():
            continue
        fields = line.split()
        if len(fields) != 4 or any(
            not re.fullmatch(r"(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})", oid)
            for oid in (fields[1], fields[3])
        ):
            print("Cannot validate malformed pre-push ref updates.", file=sys.stderr)
            return 1
        if fields[1].strip("0"):
            non_deletion_updates.append((fields[0], fields[1].lower()))
    if not non_deletion_updates:
        return NO_UPDATES_TO_CHECK

    head = subprocess.run(
        ["git", "rev-parse", "--verify", "HEAD"], cwd=root,
        capture_output=True, text=True, check=True,
    ).stdout.strip().lower()
    for local_ref, local_oid in non_deletion_updates:
        if local_oid != head:
            print(
                f"Cannot validate {local_ref}: its commit is not the checked-out HEAD. "
                "Check out the commit being pushed and run the checks there.",
                file=sys.stderr,
            )
            return 1

    tracked = subprocess.run(
        ["git", "diff", "--name-status", "HEAD", "--", *CI_INPUT_PATHS],
        cwd=root, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard", "-z", "--", *CI_INPUT_PATHS],
        cwd=root, capture_output=True, text=True, check=True,
    ).stdout.split("\0")
    changes = tracked + [f"untracked\t{path}" for path in untracked if path]
    if changes:
        print(
            "Pre-push checks require committed CI inputs. Local fixes would not be pushed with HEAD:",
            file=sys.stderr,
        )
        for change in changes[:20]:
            print(change, file=sys.stderr)
        if len(changes) > 20:
            print(f"... and {len(changes) - 20} more CI input changes.", file=sys.stderr)
        print(
            "Commit the reviewed source changes first. make ci-check remains available while editing.",
            file=sys.stderr,
        )
        return 1
    return 0


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"sdk", "verify-sdk", "generated", "pre-push"}:
        print("Usage: flutter_quality.py {sdk|verify-sdk|generated|pre-push}", file=sys.stderr)
        return 64
    if sys.argv[1] == "sdk":
        flutter, dart = sdk_pins()
        print(f"flutter={flutter}\ndart={dart}")
        return 0
    if sys.argv[1] == "verify-sdk":
        return 0 if verify_sdk() else 1
    if sys.argv[1] == "pre-push":
        return pre_push_status(updates=sys.stdin.read())
    return 0 if verify_generated_files() else 1


if __name__ == "__main__":
    raise SystemExit(main())
