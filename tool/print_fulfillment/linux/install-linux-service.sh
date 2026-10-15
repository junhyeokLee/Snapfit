#!/usr/bin/env bash
set -euo pipefail
umask 077

# Only filesystem paths and an existing OS account are arguments. Never accept
# passwords, JWTs, provider keys or environment-file contents on this command.
if [[ "$(uname -s)" != "Linux" ]]; then
  printf '%s\n' '{"error":"linux_systemd_host_required"}' >&2
  exit 78
fi
if [[ "$EUID" -ne 0 ]]; then
  printf '%s\n' '{"error":"installation_requires_root"}' >&2
  exit 78
fi
worker_node_bin=''
worker_service_user=''
worker_service_group=''
worker_replace=false
worker_arguments=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --node-bin|--project-dir|--flutter-bin|--pub-cache-dir|--service-user|--service-group|--worker-env-path)
      [[ "$#" -ge 2 ]] || exit 78
      case "$1" in
        --node-bin) worker_node_bin="$2" ;;
        --service-user) worker_service_user="$2" ;;
        --service-group) worker_service_group="$2" ;;
      esac
      worker_arguments+=("$1" "$2")
      shift 2
      ;;
    --replace) worker_replace=true; shift ;;
    *) printf '%s\n' '{"error":"invalid_install_arguments"}' >&2; exit 78 ;;
  esac
done
[[ -n "$worker_node_bin" && -n "$worker_service_user" && -n "$worker_service_group" ]] || exit 78
worker_package_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
worker_unit_path='/etc/systemd/system/snapfit-print-worker.service'
if [[ -e "$worker_unit_path" && "$worker_replace" != true ]]; then
  printf '%s\n' '{"error":"existing_unit_requires_explicit_replace"}' >&2
  exit 78
fi
command -v systemctl >/dev/null
command -v systemd-analyze >/dev/null
worker_staging_dir="$(mktemp -d)"
trap 'rm -rf -- "$worker_staging_dir"' EXIT
worker_staged_unit="$worker_staging_dir/snapfit-print-worker.service"
env -i PATH=/usr/local/bin:/usr/bin:/bin "$worker_node_bin" -- "$worker_package_dir/check-linux-host.mjs" \
  --check-install --require-pinned-runtime "${worker_arguments[@]}" --render-unit "$worker_staged_unit"
if ! systemd-analyze verify "$worker_staged_unit" >/dev/null 2>&1; then
  printf '%s\n' '{"error":"systemd_unit_verification_failed"}' >&2
  exit 78
fi
# No user, credentials, SDK, application bundle or commercial service is created.
install -d -o "$worker_service_user" -g "$worker_service_group" -m 0700 /var/lib/snapfit-print-worker
install -d -o "$worker_service_user" -g "$worker_service_group" -m 0700 /var/lib/snapfit-print-worker/tmp
install -m 0644 "$worker_staged_unit" "$worker_unit_path"
systemctl daemon-reload
printf '%s\n' '{"installed":true,"serviceStarted":false,"serviceEnabled":false,"credentialsRead":false}'
