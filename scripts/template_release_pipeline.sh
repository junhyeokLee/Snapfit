#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/template_release_pipeline.sh \
#     --store-json=assets/templates/generated/store_latest.json \
#     --base-url=http://54.253.3.176 \
#     --admin-key=xxxx
#
# Required:
#   --base-url or SNAPFIT_API_BASE_URL
#   --admin-key or SNAPFIT_PUSH_ADMIN_KEY
#
# Optional:
#   --store-json (default: assets/templates/generated/store_latest.json)
#   --cdn-manifest=PATH
#   --dry-run

STORE_JSON="assets/templates/generated/store_latest.json"
CDN_MANIFEST=""
BASE_URL="${SNAPFIT_API_BASE_URL:-}"
ADMIN_KEY="${SNAPFIT_PUSH_ADMIN_KEY:-}"
DRY_RUN="false"

for arg in "$@"; do
  case "$arg" in
    --store-json=*) STORE_JSON="${arg#*=}" ;;
    --cdn-manifest=*) CDN_MANIFEST="${arg#*=}" ;;
    --base-url=*) BASE_URL="${arg#*=}" ;;
    --admin-key=*) ADMIN_KEY="${arg#*=}" ;;
    --dry-run) DRY_RUN="true" ;;
  esac
done

if [[ -z "${BASE_URL}" ]]; then
  echo "Missing base URL. Use --base-url or SNAPFIT_API_BASE_URL" >&2
  exit 2
fi
if [[ -z "${ADMIN_KEY}" ]]; then
  echo "Missing admin key. Use --admin-key or SNAPFIT_PUSH_ADMIN_KEY" >&2
  exit 2
fi

if [[ -n "${CDN_MANIFEST}" ]]; then
  echo "[0/3] Rewrite store JSON asset URLs to CDN URLs"
  dart run tool/replace_template_asset_urls_with_cdn.dart \
    --input="${STORE_JSON}" \
    --manifest="${CDN_MANIFEST}" \
    --output="${STORE_JSON}"
fi

echo "[1/3] Template release gate"
dart run tool/template_release_gate.dart --store-json="${STORE_JSON}"

echo "[2/3] Publish templates to server"
CMD=(dart run tool/publish_store_templates_to_server.dart --input="${STORE_JSON}" --base-url="${BASE_URL}" --admin-key="${ADMIN_KEY}")
if [[ "${DRY_RUN}" == "true" ]]; then
  CMD+=(--dry-run)
fi
"${CMD[@]}"

echo "[3/3] Verify server template list"
curl -sS "${BASE_URL}/api/templates" >/dev/null
echo "Template release pipeline done."
