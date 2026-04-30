#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

HANDOFF_JSON="assets/templates/save_the_date_handoff.json"
STORE_JSON="assets/templates/generated/store_latest.json"
CDN_MANIFEST=""
PAGES="12"
BASE_URL="${SNAPFIT_API_BASE_URL:-http://54.253.3.176}"
PUBLISH="true"
NOTIFY="false"
COUNT_FOR_NOTIFY="1"

# Optional: fetch admin key from running server .env over SSH
AUTO_FETCH_ADMIN_KEY="true"
SSH_USER="ec2-user"
SSH_HOST="54.253.3.176"
SSH_KEY_PATH="../SnapFit-BackEnd/snapfit-key.pem"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_figma_template_pipeline.sh [options]

Options:
  --handoff=PATH            Handoff JSON path
  --store=PATH              Generated store template JSON output path
  --pages=N                 Page count (12~24)
  --cdn-manifest=PATH       Optional manifest to rewrite asset URLs to CDN URLs
  --base-url=URL            Backend base URL
  --publish=true|false      Publish to server
  --notify=true|false       Send template-new push notification
  --notify-count=N          Count shown in notification body
  --auto-fetch-key=true|false
                            Auto fetch SNAPFIT_PUSH_ADMIN_KEY from server .env
  --ssh-user=USER           SSH user for auto key fetch
  --ssh-host=HOST           SSH host for auto key fetch
  --ssh-key=PATH            SSH private key path for auto key fetch
  -h, --help                Show this help

Environment:
  SNAPFIT_PUSH_ADMIN_KEY    Admin key for publish/notify. If absent and
                            --auto-fetch-key=true, script will try SSH fetch.
  SNAPFIT_API_BASE_URL      Fallback for --base-url
EOF
}

for arg in "$@"; do
  case "$arg" in
    --handoff=*) HANDOFF_JSON="${arg#*=}" ;;
    --store=*) STORE_JSON="${arg#*=}" ;;
    --cdn-manifest=*) CDN_MANIFEST="${arg#*=}" ;;
    --pages=*) PAGES="${arg#*=}" ;;
    --base-url=*) BASE_URL="${arg#*=}" ;;
    --publish=*) PUBLISH="${arg#*=}" ;;
    --notify=*) NOTIFY="${arg#*=}" ;;
    --notify-count=*) COUNT_FOR_NOTIFY="${arg#*=}" ;;
    --auto-fetch-key=*) AUTO_FETCH_ADMIN_KEY="${arg#*=}" ;;
    --ssh-user=*) SSH_USER="${arg#*=}" ;;
    --ssh-host=*) SSH_HOST="${arg#*=}" ;;
    --ssh-key=*) SSH_KEY_PATH="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg"; usage; exit 2 ;;
  esac
done

echo "== Figma Template Pipeline =="
echo "handoff:   $HANDOFF_JSON"
echo "store:     $STORE_JSON"
echo "pages:     $PAGES"
echo "base-url:  $BASE_URL"

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
dart run tool/build_store_templates_from_handoff.dart \
  --input="$HANDOFF_JSON" \
  --output="$STORE_JSON" \
  --pages="$PAGES"

if [[ -n "${CDN_MANIFEST}" ]]; then
  echo ""
  echo "[1.5/4] Rewrite store JSON asset URLs to CDN URLs"
  dart run tool/replace_template_asset_urls_with_cdn.dart \
    --input="$STORE_JSON" \
    --manifest="$CDN_MANIFEST" \
    --output="$STORE_JSON"
fi

echo ""
echo "[2/4] Run release gate"
dart run tool/template_release_gate.dart --store-json="$STORE_JSON"

if [[ "$PUBLISH" != "true" ]]; then
  echo ""
  echo "publish skipped (--publish=false)"
  exit 0
fi

ADMIN_KEY="${SNAPFIT_PUSH_ADMIN_KEY:-}"
if [[ -z "$ADMIN_KEY" && "$AUTO_FETCH_ADMIN_KEY" == "true" ]]; then
  if [[ -f "$SSH_KEY_PATH" ]]; then
    echo ""
    echo "[4/5] Fetch admin key from server .env"
    chmod 400 "$SSH_KEY_PATH" || true
    ADMIN_KEY="$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$SSH_HOST" \
      "grep -E '^SNAPFIT_PUSH_ADMIN_KEY=' /opt/snapfit-backend/.env | tail -n 1 | cut -d'=' -f2-" 2>/dev/null || true)"
  fi
fi

if [[ -z "$ADMIN_KEY" ]]; then
  echo "SNAPFIT_PUSH_ADMIN_KEY missing."
  echo "Set env var or enable --auto-fetch-key with valid ssh config."
  exit 2
fi

echo ""
echo "[3/4] Publish store templates to backend"
SNAPFIT_PUSH_ADMIN_KEY="$ADMIN_KEY" \
dart run tool/publish_store_templates_to_server.dart \
  --input="$STORE_JSON" \
  --base-url="$BASE_URL"

if [[ "$NOTIFY" == "true" ]]; then
  echo ""
  echo "[4/4] Send template update push notification"
  SNAPFIT_API_BASE_URL="$BASE_URL" \
  SNAPFIT_PUSH_ADMIN_KEY="$ADMIN_KEY" \
  ./scripts/test_template_update_notification.sh "$COUNT_FOR_NOTIFY"
else
  echo ""
  echo "[4/4] Notification skipped (--notify=false)"
fi

echo ""
echo "DONE"
