#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/template_release_pipeline.sh #     --store-json=assets/templates/generated/store_latest.json #     --supabase-url=https://rrbhxdtriummqpztpjrk.supabase.co #     --admin-key=xxxx
#
# Required:
#   --admin-key or SNAPFIT_ADMIN_KEY
#
# Optional:
#   --supabase-url or SUPABASE_URL (defaults to the SnapFit Supabase project)
#   --store-json (default: assets/templates/generated/store_latest.json)
#   --cdn-manifest=PATH
#   --dry-run

STORE_JSON="assets/templates/generated/store_latest.json"
CDN_MANIFEST=""
SUPABASE_URL="${SUPABASE_URL:-https://rrbhxdtriummqpztpjrk.supabase.co}"
ADMIN_KEY="${SNAPFIT_ADMIN_KEY:-}"
DRY_RUN="false"

for arg in "$@"; do
  case "$arg" in
    --store-json=*) STORE_JSON="${arg#*=}" ;;
    --cdn-manifest=*) CDN_MANIFEST="${arg#*=}" ;;
    --supabase-url=*) SUPABASE_URL="${arg#*=}" ;;
    --admin-key=*) ADMIN_KEY="${arg#*=}" ;;
    --dry-run) DRY_RUN="true" ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [[ -z "${ADMIN_KEY}" ]]; then
  echo "Missing admin key. Use --admin-key or SNAPFIT_ADMIN_KEY" >&2
  exit 2
fi

if [[ -n "${CDN_MANIFEST}" ]]; then
  echo "[0/3] Rewrite store JSON asset URLs to CDN URLs"
  dart run tool/replace_template_asset_urls_with_cdn.dart     --input="${STORE_JSON}"     --manifest="${CDN_MANIFEST}"     --output="${STORE_JSON}"
fi

echo "[1/3] Template release gate"
dart run tool/template_release_gate.dart --store-json="${STORE_JSON}"

echo "[2/3] Publish templates through Supabase admin-ops"
CMD=(dart run tool/publish_store_templates_to_server.dart --input="${STORE_JSON}" --supabase-url="${SUPABASE_URL}" --admin-key="${ADMIN_KEY}")
if [[ "${DRY_RUN}" == "true" ]]; then
  CMD+=(--dry-run)
fi
"${CMD[@]}"

echo "[3/3] Code-only Supabase readiness audit"
python3 tool/supabase_readiness_check.py --skip-remote

echo "Template release pipeline done."
