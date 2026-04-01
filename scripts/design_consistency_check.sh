#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[1/2] UI consistency gate"
dart run tool/ui_consistency_gate.dart

echo "[2/2] Template release gate"
dart run tool/template_release_gate.dart

echo "Design consistency checks passed."

