#!/usr/bin/env bash
# CI-equivalent local/pre-push check: bash scripts/check_flutter_quality.sh all
# Regeneration writes generated Dart sources; review and commit any differences.
set -euo pipefail

quality_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$quality_root"
quality_stage="${1:-all}"

case "$quality_stage" in
  --help|-h)
    echo 'Usage: bash scripts/check_flutter_quality.sh [all|deps|generated|format|analyze|audits|test|sdk]'
    echo 'all runs the same pinned-SDK checks and single full test run as CI.'
    exit 0
    ;;
  sdk)
    python3 tool/ci/flutter_quality.py sdk
    exit 0
    ;;
  all|deps|generated|format|analyze|audits|test) ;;
  *)
    echo "Unknown quality stage: $quality_stage" >&2
    exit 64
    ;;
esac

python3 tool/ci/flutter_quality.py verify-sdk

quality_format() {
  dart format --output=none --set-exit-if-changed \
    lib test tool/ai_contract_generator.dart \
    tool/generate_ai_composition.dart tool/generate_ai_typography.dart
}

quality_generated() {
  dart run build_runner build --delete-conflicting-outputs
  # build_runner does not own these standalone contract files and can remove
  # conflicting .g.dart outputs, so restore them after the builder finishes.
  dart run tool/generate_ai_composition.dart
  dart run tool/generate_ai_typography.dart
  quality_format
  dart run tool/generate_ai_composition.dart --check
  dart run tool/generate_ai_typography.dart --check
  python3 tool/ci/flutter_quality.py generated
}

quality_audits() {
  python3 -m unittest discover -s tool/ci -p 'test_*.py'
  python3 tool/supabase_readiness_check.py --skip-remote
  python3 tool/template_quality_check.py
}

case "$quality_stage" in
  deps) flutter pub get --enforce-lockfile ;;
  generated) quality_generated ;;
  format) quality_format ;;
  analyze) flutter analyze --no-pub ;;
  audits) quality_audits ;;
  test) flutter test --no-pub --concurrency=2 ;;
  all)
    flutter pub get --enforce-lockfile
    quality_generated
    flutter analyze --no-pub
    quality_audits
    flutter test --no-pub --concurrency=2
    ;;
esac
