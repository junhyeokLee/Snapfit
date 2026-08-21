#!/usr/bin/env bash
set -euo pipefail

cat >&2 <<'EOF'
Template update push notification is no longer sent through the legacy Spring REST endpoint.
Add a Supabase Edge Function/admin-ops action for template-topic notifications before re-enabling this script.
EOF
exit 2
