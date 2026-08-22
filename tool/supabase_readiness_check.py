#!/usr/bin/env python3
"""SnapFit Supabase production readiness audit.

This script checks configuration and code readiness without printing secret values.
It is safe to run in CI or on the VPS. It only reports secret names as present/missing.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT_REF_DEFAULT = "rrbhxdtriummqpztpjrk"
FUNCTIONS = {
    "iap-verify": {"method": "OPTIONS", "expected": {200}},
    "address-search": {"method": "OPTIONS", "expected": {200}},
    "order-checkout": {"method": "OPTIONS", "expected": {200}},
    "admin-ops": {"method": "OPTIONS", "expected": {200}},
    "account-delete": {"method": "OPTIONS", "expected": {200}},
    "album-invites": {"method": "OPTIONS", "expected": {200}},
    "order-confirm-payment": {"method": "OPTIONS", "expected": {200}},
    "billing-prepare": {"method": "OPTIONS", "expected": {200}},
    "billing-approve": {"method": "OPTIONS", "expected": {200}},
    "billing-webhook": {"method": "OPTIONS", "expected": {200}},
}
REQUIRED_SECRETS = {
    "android_iap": [
        ["GOOGLE_PLAY_PACKAGE_NAME"],
        ["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL+GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY"],
    ],
    "ios_iap": [["APP_STORE_ISSUER_ID"], ["APP_STORE_KEY_ID"], ["APP_STORE_BUNDLE_ID"], ["APP_STORE_PRIVATE_KEY"], ["APP_STORE_ENVIRONMENT"]],
    "operations": [["SNAPFIT_ADDRESS_JUSO_KEY"], ["SNAPFIT_ORDER_CHECKOUT_BASE_URL"], ["SNAPFIT_ADMIN_KEY"]],
}
FORBIDDEN_PATTERNS = [
    "assertLegacyBackendFallbackAllowed",
    "ENABLE_LEGACY_BACKEND_FALLBACK",
    "Env.baseUrl",
    "dio_provider",
    "DioClient",
    "AuthInterceptor",
    "/api/auth",
    "/api/billing",
    "/api/notifications",
    "/api/support",
    "/api/orders",
    "/api/admin",
    "SNAPFIT_BILLING_MOCK_MODE",
    "real_payment_provider_not_configured",
    "billing_webhook_not_implemented_yet",
]

@dataclass
class Check:
    name: str
    ok: bool
    detail: str


def run(cmd: list[str], *, cwd: pathlib.Path = ROOT, timeout: int = 60) -> tuple[int, str]:
    proc = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, timeout=timeout)
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def supabase_token() -> str:
    if os.environ.get("SUPABASE_ACCESS_TOKEN"):
        return os.environ["SUPABASE_ACCESS_TOKEN"]
    token_file = pathlib.Path("/opt/data/.supabase/access-token")
    if token_file.exists():
        return token_file.read_text().strip()
    return ""


def secret_names(project_ref: str) -> tuple[set[str], str]:
    env = os.environ.copy()
    env["SUPABASE_TELEMETRY_DISABLED"] = "1"
    token = supabase_token()
    if token:
        env["SUPABASE_ACCESS_TOKEN"] = token
    proc = subprocess.run(
        ["npx", "--yes", "supabase@latest", "secrets", "list", "--project-ref", project_ref],
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=120,
        env=env,
    )
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode != 0:
        return set(), out or "supabase CLI returned a non-zero exit code"
    raw = proc.stdout.strip()
    if not raw:
        return set(), "supabase CLI returned empty output; run `npx supabase@latest login` or set SUPABASE_ACCESS_TOKEN, then retry"
    try:
        data = json.loads(raw)
        return {item["name"] for item in data.get("secrets", [])}, ""
    except json.JSONDecodeError:
        # Recent Supabase CLI versions may print an ASCII table instead of JSON
        # even when the command exits successfully. Parse only the NAME column.
        names: set[str] = set()
        for line in raw.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("NAME") or stripped.startswith("---"):
                continue
            if "|" not in stripped:
                continue
            name = stripped.split("|", 1)[0].strip()
            if name and name != "NAME":
                names.add(name)
        if names:
            return names, ""
        preview = raw[:500].replace("\n", " ")
        return set(), f"supabase CLI returned unparseable output: {preview}"


def group_present(names: set[str], group: list[str]) -> bool:
    for option in group:
        if "+" in option:
            if all(part in names for part in option.split("+")):
                return True
        elif option in names:
            return True
    return False


def check_secrets(project_ref: str) -> list[Check]:
    names, error = secret_names(project_ref)
    if error:
        return [Check("supabase secrets", False, f"unable to list secrets: {error}")]
    checks: list[Check] = []
    for area, groups in REQUIRED_SECRETS.items():
        missing = [" or ".join(group) for group in groups if not group_present(names, group)]
        checks.append(Check(f"secrets:{area}", not missing, "missing: " + ", ".join(missing) if missing else "all required names present"))
    return checks


def check_forbidden_patterns() -> Check:
    paths = [p for p in (ROOT / "lib").rglob("*.dart")]
    paths += [p for p in (ROOT / "tool").rglob("*.dart")]
    paths += [p for p in (ROOT / "scripts").rglob("*.sh")]
    paths += [ROOT / "Makefile"]
    paths += [p for p in (ROOT / "supabase" / "functions").rglob("*.ts")]
    hits: list[str] = []
    for path in paths:
        text = path.read_text(errors="ignore")
        for pattern in FORBIDDEN_PATTERNS:
            if pattern in text:
                hits.append(f"{path.relative_to(ROOT)}:{pattern}")
    return Check("legacy backend patterns", not hits, "none found" if not hits else "; ".join(hits[:20]))


def check_function_options(project_ref: str) -> list[Check]:
    checks: list[Check] = []
    base = f"https://{project_ref}.supabase.co/functions/v1"
    for fn, cfg in FUNCTIONS.items():
        req = urllib.request.Request(f"{base}/{fn}", method=cfg["method"])
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                status = resp.status
        except urllib.error.HTTPError as e:
            status = e.code
        except Exception as e:  # network/DNS/etc.
            checks.append(Check(f"function:{fn}", False, f"request failed: {e}"))
            continue
        checks.append(Check(f"function:{fn}", status in cfg["expected"], f"OPTIONS status {status}"))
    return checks


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-ref", default=PROJECT_REF_DEFAULT)
    parser.add_argument("--skip-remote", action="store_true", help="skip Supabase remote checks")
    args = parser.parse_args()

    checks = [check_forbidden_patterns()]
    if not args.skip_remote:
        checks.extend(check_secrets(args.project_ref))
        checks.extend(check_function_options(args.project_ref))

    for check in checks:
        mark = "✅" if check.ok else "❌"
        print(f"{mark} {check.name}: {check.detail}")
    failed = [c for c in checks if not c.ok]
    if failed:
        print(f"\nNOT READY: {len(failed)} check(s) failed.")
        return 1
    print("\nREADY: all checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
