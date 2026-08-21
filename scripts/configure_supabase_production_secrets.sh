#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-rrbhxdtriummqpztpjrk}"

read_value() {
  local name="$1"
  local secret_flag="${2:-secret}"
  local value=""
  if [[ "$secret_flag" == "plain" ]]; then
    read -r -p "$name: " value
  else
    read -r -s -p "$name: " value
    echo ""
  fi
  printf '%s' "$value"
}

set_if_present() {
  local name="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set --project-ref "$PROJECT_REF" "$name=$value"
  else
    echo "skip $name"
  fi
}

cat <<EOF
SnapFit Supabase production secret configurator

- Values are typed into this terminal only.
- Input is hidden for secret fields.
- Leave a field empty to skip it.
- After setting values, the readiness check runs automatically.

Project ref: $PROJECT_REF
EOF

ADMIN_KEY="$(read_value SNAPFIT_ADMIN_KEY)"
JUSO_KEY="$(read_value SNAPFIT_ADDRESS_JUSO_KEY)"
CHECKOUT_URL="$(read_value SNAPFIT_ORDER_CHECKOUT_BASE_URL plain)"
GOOGLE_PACKAGE="$(read_value GOOGLE_PLAY_PACKAGE_NAME plain)"
GOOGLE_JSON="$(read_value GOOGLE_PLAY_SERVICE_ACCOUNT_JSON)"
APP_ISSUER="$(read_value APP_STORE_ISSUER_ID plain)"
APP_KEY_ID="$(read_value APP_STORE_KEY_ID plain)"
APP_BUNDLE="$(read_value APP_STORE_BUNDLE_ID plain)"
APP_PRIVATE_KEY="$(read_value APP_STORE_PRIVATE_KEY)"
APP_ENV="$(read_value APP_STORE_ENVIRONMENT plain)"

set_if_present SNAPFIT_ADMIN_KEY "$ADMIN_KEY"
set_if_present SNAPFIT_ADDRESS_JUSO_KEY "$JUSO_KEY"
set_if_present SNAPFIT_ORDER_CHECKOUT_BASE_URL "$CHECKOUT_URL"
set_if_present GOOGLE_PLAY_PACKAGE_NAME "$GOOGLE_PACKAGE"
set_if_present GOOGLE_PLAY_SERVICE_ACCOUNT_JSON "$GOOGLE_JSON"
set_if_present APP_STORE_ISSUER_ID "$APP_ISSUER"
set_if_present APP_STORE_KEY_ID "$APP_KEY_ID"
set_if_present APP_STORE_BUNDLE_ID "$APP_BUNDLE"
set_if_present APP_STORE_PRIVATE_KEY "$APP_PRIVATE_KEY"
set_if_present APP_STORE_ENVIRONMENT "${APP_ENV:-sandbox}"

python3 tool/supabase_readiness_check.py --project-ref "$PROJECT_REF"
