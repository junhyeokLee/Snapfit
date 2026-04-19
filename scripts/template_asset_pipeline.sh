#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

TEMPLATE_SLUG=""
VERSION="v1"
CDN_BASE_URL=""
STORE_JSON="assets/templates/generated/store_latest.json"
TEMPLATE_STORE_JSON=""
CONFIG_PATH="assets/templates/workspace/template_cdn_config.json"
REGISTRY_PATH="assets/templates/workspace/template_registry.json"
SKIP_UPLOAD="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/template_asset_pipeline.sh \
    --template-slug=save_the_date \
    --version=v1 \
    --cdn-base-url=https://cdn.snapfit.app

Options:
  --template-slug=SLUG      Template slug
  --version=VERSION         Path version, default v1
  --cdn-base-url=URL        Public CDN/Firebase base url
  --store-json=PATH         Store JSON path
  --template-store-json=PATH Per-template store JSON path
  --config=PATH             Global CDN config path
  --registry=PATH           Template registry path
  --skip-upload=true        Skip Firebase upload and only validate/rewrite
EOF
}

for arg in "$@"; do
  case "$arg" in
    --template-slug=*) TEMPLATE_SLUG="${arg#*=}" ;;
    --version=*) VERSION="${arg#*=}" ;;
    --cdn-base-url=*) CDN_BASE_URL="${arg#*=}" ;;
    --store-json=*) STORE_JSON="${arg#*=}" ;;
    --template-store-json=*) TEMPLATE_STORE_JSON="${arg#*=}" ;;
    --config=*) CONFIG_PATH="${arg#*=}" ;;
    --registry=*) REGISTRY_PATH="${arg#*=}" ;;
    --skip-upload=*) SKIP_UPLOAD="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg"; usage; exit 2 ;;
  esac
done

if [[ -z "$TEMPLATE_SLUG" ]]; then
  echo "Missing --template-slug" >&2
  exit 2
fi

if [[ "$SKIP_UPLOAD" == "true" && -z "$CDN_BASE_URL" ]]; then
  echo "Missing --cdn-base-url" >&2
  exit 2
fi

MANIFEST_PATH="assets/templates/${TEMPLATE_SLUG}/cdn_manifest.json"
if [[ -z "$TEMPLATE_STORE_JSON" ]]; then
  TEMPLATE_STORE_JSON="assets/templates/generated/${TEMPLATE_SLUG}_store.json"
fi

if [[ "$SKIP_UPLOAD" != "true" ]]; then
  echo "[1/6] Upload local images to Firebase and write CDN manifest"
  dart run tool/upload_template_assets_to_firebase.dart \
    --template-slug="$TEMPLATE_SLUG" \
    --config="$CONFIG_PATH" \
    --manifest="$MANIFEST_PATH" \
    --store-json="$TEMPLATE_STORE_JSON"
else
  echo "[1/6] Skip Firebase upload"
  echo "[2/6] Build CDN manifest fallback"
  dart run tool/build_template_cdn_manifest.dart \
    --template-slug="$TEMPLATE_SLUG" \
    --version="$VERSION" \
    --cdn-base-url="$CDN_BASE_URL"
fi

echo "[3/6] Validate asset pipeline"
dart run tool/validate_template_asset_pipeline.dart \
  --template-slug="$TEMPLATE_SLUG" \
  --manifest="$MANIFEST_PATH" \
  --store-json="$TEMPLATE_STORE_JSON"

echo "[4/6] Rewrite per-template store JSON asset URLs to CDN URLs"
dart run tool/replace_template_asset_urls_with_cdn.dart \
  --input="$TEMPLATE_STORE_JSON" \
  --manifest="$MANIFEST_PATH" \
  --output="$TEMPLATE_STORE_JSON"

echo "[5/6] Merge per-template store JSON into store_latest safely"
dart run tool/merge_generated_template_into_store.dart \
  --input="$TEMPLATE_STORE_JSON" \
  --output="$STORE_JSON" \
  --registry="$REGISTRY_PATH"

echo "[6/6] Validate approved template registry invariants"
dart run tool/template_registry_guard.dart \
  --store-json="$STORE_JSON" \
  --registry="$REGISTRY_PATH"

echo "Template asset pipeline done."
