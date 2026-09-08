#!/usr/bin/env bash
set -euo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      cat <<'HELP'
Usage: scripts/configure_supabase_production_secrets.sh

Configure SnapFit point IAP, push, AI and operations secrets.
HELP
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

PROJECT_REF="${SUPABASE_PROJECT_REF:-rrbhxdtriummqpztpjrk}"
if [[ "$PROJECT_REF" != "rrbhxdtriummqpztpjrk" ]]; then
  echo "Refusing to configure a different project. This script targets only SnapFit rrbhxdtriummqpztpjrk." >&2
  exit 1
fi
ENV_FILE="$(mktemp)"
chmod 600 "$ENV_FILE"
trap 'rm -f "$ENV_FILE"' EXIT

read_value() {
  local name="$1"
  local secret_flag="${2:-secret}"
  local default_value="${3:-}"
  local prompt="$name"
  local value=""
  if [[ -n "$default_value" ]]; then
    prompt="$prompt [$default_value]"
  fi
  if [[ "$secret_flag" == "plain" ]]; then
    read -r -p "$prompt: " value
  else
    read -r -s -p "$prompt: " value
    echo "" >&2
  fi
  if [[ -z "$value" ]]; then
    value="$default_value"
  fi
  printf '%s' "$value"
}

append_if_present() {
  local name="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    # Use a temporary env file so secret values are not exposed as CLI args.
    NAME="$name" VALUE="$value" python3 - <<'PYENV' >> "$ENV_FILE"
import os
name = os.environ['NAME']
value = os.environ['VALUE']
# A JSON credential contains escaped PEM newlines. Double-quoted dotenv values
# decode those escapes again in the Supabase CLI and can corrupt the JSON/key.
if "'" not in value and '\n' not in value and '\r' not in value:
    print(f"{name}='{value}'")
else:
    # Interactive inputs are one line. Multiline/private key inputs should use
    # literal \\n as explained above so they can be preserved verbatim.
    raise SystemExit(f'{name}: use a single-line value without apostrophes; nothing was uploaded')
PYENV
    echo "queued $name"
  else
    echo "skip $name"
  fi
}

cat <<EOF
SnapFit Supabase production secret configurator

- Values are typed into this terminal only; do not paste them in chat.
- Secret inputs are hidden.
- Values are written to a temporary chmod 600 env file, sent with --env-file, then deleted.
- Leave a field empty to skip it, except defaults shown in brackets.
- For private keys, paste with literal \\n line breaks if your dashboard provides a single-line value.

Project ref: $PROJECT_REF
EOF

OPENAI_KEY="$(read_value OPENAI_API_KEY)"
OPENAI_MODEL="$(read_value OPENAI_MODEL plain gpt-4o)"
ANTHROPIC_KEY="$(read_value ANTHROPIC_API_KEY)"
ANTHROPIC_MODEL="$(read_value ANTHROPIC_MODEL plain claude-sonnet-4-5)"
AI_PROVIDER="$(read_value AI_ALBUM_DRAFT_PROVIDER plain hybrid)"
AI_TIMEOUT="$(read_value AI_ALBUM_DRAFT_TIMEOUT_MS plain 20000)"
GOOGLE_PACKAGE="$(read_value GOOGLE_PLAY_PACKAGE_NAME plain)"
GOOGLE_JSON="$(read_value GOOGLE_PLAY_SERVICE_ACCOUNT_JSON)"
GOOGLE_EMAIL="$(read_value GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL plain)"
GOOGLE_PRIVATE_KEY="$(read_value GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY)"
APP_ISSUER="$(read_value APP_STORE_ISSUER_ID plain)"
APP_KEY_ID="$(read_value APP_STORE_KEY_ID plain)"
APP_BUNDLE="$(read_value APP_STORE_BUNDLE_ID plain)"
APP_PRIVATE_KEY="$(read_value APP_STORE_PRIVATE_KEY)"
APP_ENV="$(read_value APP_STORE_ENVIRONMENT plain production)"
ADMIN_KEY="$(read_value SNAPFIT_ADMIN_KEY)"
JUSO_KEY="$(read_value SNAPFIT_ADDRESS_JUSO_KEY)"

append_if_present OPENAI_API_KEY "$OPENAI_KEY"
append_if_present OPENAI_MODEL "$OPENAI_MODEL"
append_if_present ANTHROPIC_API_KEY "$ANTHROPIC_KEY"
append_if_present ANTHROPIC_MODEL "$ANTHROPIC_MODEL"
append_if_present AI_ALBUM_DRAFT_PROVIDER "$AI_PROVIDER"
append_if_present AI_ALBUM_DRAFT_TIMEOUT_MS "$AI_TIMEOUT"
append_if_present GOOGLE_PLAY_PACKAGE_NAME "$GOOGLE_PACKAGE"
append_if_present GOOGLE_PLAY_SERVICE_ACCOUNT_JSON "$GOOGLE_JSON"
append_if_present GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL "$GOOGLE_EMAIL"
append_if_present GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY "$GOOGLE_PRIVATE_KEY"
append_if_present APP_STORE_ISSUER_ID "$APP_ISSUER"
append_if_present APP_STORE_KEY_ID "$APP_KEY_ID"
append_if_present APP_STORE_BUNDLE_ID "$APP_BUNDLE"
append_if_present APP_STORE_PRIVATE_KEY "$APP_PRIVATE_KEY"
append_if_present APP_STORE_ENVIRONMENT "$APP_ENV"
append_if_present SNAPFIT_ADMIN_KEY "$ADMIN_KEY"
append_if_present SNAPFIT_ADDRESS_JUSO_KEY "$JUSO_KEY"

# Service/worker keys belong only to Supabase; never copy these into Flutter defines.
# SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY are managed by Supabase; do not prompt for them.
for setting in \
  SNAPFIT_IAP_RECONCILE_SECRET \
  PUSH_DISPATCH_SECRET \
  FIREBASE_SERVICE_ACCOUNT_JSON; do
  setting_value="$(read_value "$setting")"
  append_if_present "$setting" "$setting_value"
done
# Push delivery stays disabled until credentials, device registration and schedule are verified.
setting_value="$(read_value PUSH_DELIVERY_ENABLED plain false)"
append_if_present PUSH_DELIVERY_ENABLED "$setting_value"

if [[ ! -s "$ENV_FILE" ]]; then
  echo "No values queued. Nothing to set."
  exit 0
fi

SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set --project-ref "$PROJECT_REF" --env-file "$ENV_FILE"
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets list --project-ref "$PROJECT_REF"
python3 tool/supabase_readiness_check.py --project-ref "$PROJECT_REF"
