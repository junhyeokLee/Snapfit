#!/usr/bin/env bash
# Opt in only: bash tool/install_pre_push_hook.sh
set -euo pipefail

install_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$install_root"
if install_hooks="$(git config --get core.hooksPath)"; then
  :
else
  install_status=$?
  if [[ "$install_status" != 1 ]]; then
    exit "$install_status"
  fi
  install_hooks=''
fi
if [[ "$install_hooks" == '.githooks' ]]; then
  echo 'The repository already uses .githooks; no configuration changed.'
  exit 0
fi
if [[ -n "$install_hooks" ]]; then
  echo "Existing hooksPath is preserved: $install_hooks" >&2
  echo 'Run make ci-check manually, or integrate it into your existing hook.' >&2
  exit 1
fi
install_hook_directory="$(git rev-parse --git-path hooks)"
shopt -s nullglob dotglob
for install_existing in "$install_hook_directory"/*; do
  [[ "$install_existing" == *.sample ]] && continue
  if [[ -f "$install_existing" || -L "$install_existing" ]]; then
    echo "Existing hook is preserved: $install_existing" >&2
    echo 'Changing hooksPath would disable it. Run make ci-check manually, or integrate it into your existing hooks.' >&2
    exit 1
  fi
done
if [[ ! -x .githooks/pre-push ]]; then
  echo '.githooks/pre-push must be executable before installation.' >&2
  exit 1
fi
git config --local core.hooksPath .githooks
echo 'Installed the optional repository-local pre-push check.'
