"""Offline checks for point/push readiness and retired external checkout."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "snapfit_readiness", ROOT / "tool/supabase_readiness_check.py"
)
readiness = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = readiness
SPEC.loader.exec_module(readiness)


def names_for(groups_by_area):
    return {
        name
        for groups in groups_by_area.values()
        for alternatives in groups
        for name in alternatives[0].split("+")
    }


class ReadinessScopeTests(unittest.TestCase):
    def setUp(self):
        self.point_push_names = names_for(readiness.REQUIRED_SECRET_PROFILES["production"])

    def test_production_passes_without_physical_order_secrets(self):
        self.assertFalse(any("PORTONE" in name or "CHECKOUT" in name for name in self.point_push_names))
        with patch.object(readiness, "secret_names", return_value=(self.point_push_names, "")):
            checks = readiness.check_secrets("offline-test", "production")
        self.assertTrue(all(check.ok for check in checks), checks)
        self.assertEqual(
            {check.name for check in checks},
            {"secrets:android_iap", "secrets:ios_iap", "secrets:point_refunds", "secrets:push", "secrets:operations"},
        )

    def test_retired_checkout_cannot_be_enabled_by_readiness_flag(self):
        with patch.object(sys, "argv", ["readiness", "--include-physical-orders"]):
            with patch.object(readiness, "secret_names") as remote_secrets:
                with patch.object(readiness.urllib.request, "urlopen") as remote_http:
                    with self.assertRaises(SystemExit) as error:
                        readiness.main()
        self.assertEqual(error.exception.code, 2)
        remote_secrets.assert_not_called()
        remote_http.assert_not_called()

    def test_existing_core_profile_still_only_requires_android_and_operations(self):
        names = names_for(readiness.REQUIRED_SECRET_PROFILES["supabase-core"])
        with patch.object(readiness, "secret_names", return_value=(names, "")):
            checks = readiness.check_secrets("offline-test", "supabase-core")
        self.assertTrue(all(check.ok for check in checks), checks)
        self.assertEqual(
            {check.name for check in checks},
            {"secrets:android_iap", "secrets:operations", "deferred:ios_iap"},
        )

    def check_function_scope(self):
        called = []

        class Response:
            def __init__(self, status):
                self.status = status

            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

        def fake_open(request, timeout):
            name = request.full_url.rsplit("/", 1)[-1]
            called.append(name)
            return Response(405 if name == "push-dispatch" else 200)

        with patch.object(readiness.urllib.request, "urlopen", side_effect=fake_open):
            checks = readiness.check_function_options("offline-test")
        return called, checks

    def test_default_does_not_probe_physical_payment_functions(self):
        called, checks = self.check_function_scope()
        self.assertTrue(all(check.ok for check in checks), checks)
        self.assertFalse(set(called) & {"order-checkout", "order-confirm-payment", "order-payment-webhook"})
        self.assertIn("iap-verify", called)
        self.assertIn("push-dispatch", called)



class SecretConfiguratorScopeTests(unittest.TestCase):
    def run_configurator(self, *args):
        # All CLI/network boundaries are replaced; no secret or project is read.
        with tempfile.TemporaryDirectory(prefix=".secret-script-test-", dir=ROOT) as directory:
            temp = Path(directory)
            npx = temp / "npx"
            npx.write_text(
                f"#!{sys.executable}\n"
                "import json, os, pathlib, sys\n"
                "root = pathlib.Path(os.environ['SNAPFIT_TEST_CAPTURE'])\n"
                "with (root / 'cli_calls').open('a') as output:\n"
                "    output.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                "if '--env-file' in sys.argv:\n"
                "    source = pathlib.Path(sys.argv[sys.argv.index('--env-file') + 1])\n"
                "    (root / 'uploaded_env').write_text(source.read_text())\n"
            )
            python = temp / "python3"
            python.write_text(
                f"#!{sys.executable}\n"
                "import json, os, pathlib, sys\n"
                "if len(sys.argv) > 1 and sys.argv[1] == 'tool/supabase_readiness_check.py':\n"
                "    target = pathlib.Path(os.environ['SNAPFIT_TEST_CAPTURE']) / 'readiness_args'\n"
                "    target.write_text(json.dumps(sys.argv[2:]))\n"
                "else:\n"
                f"    os.execv({sys.executable!r}, [{sys.executable!r}, *sys.argv[1:]])\n"
            )
            npx.chmod(0o700)
            python.chmod(0o700)
            env = dict(os.environ)
            env.update({
                "PATH": f"{temp}:{env.get('PATH', '')}",
                "TMPDIR": str(temp),
                "SUPABASE_PROJECT_REF": readiness.PROJECT_REF_DEFAULT,
                "SNAPFIT_TEST_CAPTURE": str(temp),
            })
            result = subprocess.run(
                ["bash", "scripts/configure_supabase_production_secrets.sh", *args],
                cwd=ROOT, env=env, input="\n" * 40, text=True, capture_output=True, timeout=20,
            )
            files = {
                name: (temp / name).read_text() if (temp / name).exists() else None
                for name in ("uploaded_env", "readiness_args", "cli_calls")
            }
        return result, files

    def test_default_configuration_skips_all_physical_payment_prompts(self):
        result, files = self.run_configurator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("SNAPFIT_ORDER_", result.stdout + result.stderr)
        self.assertNotIn("SNAPFIT_ORDER_", files["uploaded_env"])
        self.assertEqual(json.loads(files["readiness_args"]), ["--project-ref", readiness.PROJECT_REF_DEFAULT])
        self.assertIn("skip SNAPFIT_IAP_RECONCILE_SECRET", result.stdout)
        self.assertIn("PUSH_DELIVERY_ENABLED='false'", files["uploaded_env"])

    def test_retired_checkout_flag_does_not_configure_anything(self):
        result, files = self.run_configurator("--include-physical-orders")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("Unknown option", result.stderr)
        self.assertTrue(all(value is None for value in files.values()), files)

    def test_help_and_invalid_arguments_do_not_configure_anything(self):
        for args, status in [(("--help",), 0), (("--unknown",), 2)]:
            with self.subTest(args=args):
                result, files = self.run_configurator(*args)
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertIsNone(files["cli_calls"])
                self.assertIsNone(files["readiness_args"])


if __name__ == "__main__":
    unittest.main()
