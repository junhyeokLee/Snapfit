#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

HANDOFF_JSON="assets/templates/save_the_date_handoff.json"
STORE_JSON="assets/templates/generated/store_latest.json"
CDN_MANIFEST=""
PAGES="12"
SUPABASE_URL="${SUPABASE_URL:-https://rrbhxdtriummqpztpjrk.supabase.co}"
PUBLISH="true"
NOTIFY="false"
COUNT_FOR_NOTIFY="1"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_figma_template_pipeline.sh [options]

Options:
  --handoff=PATH            Handoff JSON path
  --store=PATH              Generated store template JSON output path
  --pages=N                 Page count (12~24)
  --cdn-manifest=PATH       Optional manifest to rewrite asset URLs to CDN URLs
  --supabase-url=URL        Supabase project URL
  --publish=true|false      Publish through Supabase admin-ops
  --notify=true|false       Currently disabled until Supabase notification action exists
  --notify-count=N          Count shown in future notification body
  -h, --help                Show this help

Environment:
  SUPABASE_URL              Fallback for --supabase-url
  SNAPFIT_ADMIN_KEY         Admin key for publish
EOF
}

for arg in "$@"; do
  case "$arg" in
    --handoff=*) HANDOFF_JSON="${arg#*=}" ;;
    --store=*) STORE_JSON="${arg#*=}" ;;
    --cdn-manifest=*) CDN_MANIFEST="${arg#*=}" ;;
    --pages=*) PAGES="${arg#*=}" ;;
    --supabase-url=*) SUPABASE_URL="${arg#*=}" ;;
    --publish=*) PUBLISH="${arg#*=}" ;;
    --notify=*) NOTIFY="${arg#*=}" ;;
    --notify-count=*) COUNT_FOR_NOTIFY="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg"; usage; exit 2 ;;
  esac
done

echo "== Figma Template Pipeline =="
echo "handoff:      $HANDOFF_JSON"
echo "store:        $STORE_JSON"
echo "pages:        $PAGES"
echo "supabase-url: $SUPABASE_URL"

if [[ ! -f "$HANDOFF_JSON" ]]; then
  echo "Handoff JSON not found: $HANDOFF_JSON"
  exit 2
fi

if ! [[ "$PAGES" =~ ^[0-9]+$ ]]; then
  echo "--pages must be a number"
  exit 2
fi
if (( PAGES < 12 || PAGES > 24 )); then
  echo "--pages must be in range 12..24"
  exit 2
fi

echo ""
echo "[1/4] Build store templates (cover + pages)"
dart run tool/build_store_templates_from_handoff.dart   --input="$HANDOFF_JSON"   --output="$STORE_JSON"   --pages="$PAGES"

if [[ -n "${CDN_MANIFEST}" ]]; then
  echo ""
  echo "[1.5/4] Rewrite store JSON asset URLs to CDN URLs"
  dart run tool/replace_template_asset_urls_with_cdn.dart     --input="$STORE_JSON"     --manifest="$CDN_MANIFEST"     --output="$STORE_JSON"
fi

echo ""
echo "[2/4] Run release gate"
dart run tool/template_release_gate.dart --store-json="$STORE_JSON"

if [[ "$PUBLISH" != "true" ]]; then
  echo ""
  echo "publish skipped (--publish=false)"
  exit 0
fi

ADMIN_KEY="${SNAPFIT_ADMIN_KEY:-}"
if [[ -z "$ADMIN_KEY" ]]; then
  echo "SNAPFIT_ADMIN_KEY missing."
  echo "Set it as a Supabase admin-ops key before publishing."
  exit 2
fi

echo ""
echo "[3/4] Publish store templates through Supabase admin-ops"
dart run tool/publish_store_templates_to_server.dart   --input="$STORE_JSON"   --supabase-url="$SUPABASE_URL"   --admin-key="$ADMIN_KEY"

if [[ "$NOTIFY" == "true" ]]; then
  echo ""
  echo "[4/4] Template notification disabled"
  ./scripts/test_template_update_notification.sh "$COUNT_FOR_NOTIFY"
else
  echo ""
  echo "[4/4] Notification skipped (--notify=false)"
fi

echo ""
echo "DONE"
