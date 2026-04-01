#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SNAPFIT_API_BASE_URL:-}" ]]; then
  echo "SNAPFIT_API_BASE_URL is required"
  exit 1
fi

if [[ -z "${SNAPFIT_PUSH_ADMIN_KEY:-}" ]]; then
  echo "SNAPFIT_PUSH_ADMIN_KEY is required"
  exit 1
fi

COUNT="${1:-3}"
TODAY="$(TZ=Asia/Seoul date +%Y.%m.%d)"

echo "Sending template update notification: count=${COUNT}, date=${TODAY}"

curl -sS -X POST "${SNAPFIT_API_BASE_URL}/api/notifications/topic" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: ${SNAPFIT_PUSH_ADMIN_KEY}" \
  -d "{
    \"topic\": \"snapfit_template_new\",
    \"title\": \"새 템플릿 업데이트\",
    \"body\": \"${TODAY} 신규 템플릿 ${COUNT}개가 추가되었어요.\",
    \"dryRun\": false,
    \"data\": {
      \"type\": \"template_new\",
      \"source\": \"manual_test\",
      \"count\": \"${COUNT}\"
    }
  }"

echo ""
echo "done"
