import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import flutter_quality


def isolated_git_environment():
    environment = dict(os.environ)
    for name in (
        "GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    ):
        environment.pop(name, None)
    environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    return environment


class GeneratedSourceGuardTest(unittest.TestCase):
    def setUp(self):
        environment = patch.dict(os.environ, isolated_git_environment(), clear=True)
        environment.start()
        self.addCleanup(environment.stop)
        self.directory = tempfile.TemporaryDirectory(prefix="snapfit-ci-guard-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git("init", "--quiet")
        self.generated = self.root / "lib/example.g.dart"
        self.generated.parent.mkdir()
        self.generated.write_text("const generatedValue = 1;\n", encoding="utf-8")
        (self.root / "lib/ordinary.dart").write_text("const value = 1;\n", encoding="utf-8")
        self.git("add", ".")
        self.git(
            "-c", "core.hooksPath=/dev/null", "-c", "user.name=CI guard test",
            "-c", "user.email=ci-guard@example.invalid", "commit", "--quiet", "--no-gpg-sign",
            "-m", "Test baseline",
        )

    def git(self, *args):
        return subprocess.run(
            ["git", *args], cwd=self.root, check=True, capture_output=True,
            text=True, env=isolated_git_environment(),
        )

    def check(self):
        with contextlib.redirect_stderr(io.StringIO()):
            return flutter_quality.verify_generated_files(self.root)

    def updates(self, oid=None):
        head = self.git("rev-parse", "HEAD").stdout.strip()
        return f"refs/heads/main {oid or head} refs/heads/main {'0' * len(head)}\n"

    def push_status(self, updates=None):
        with contextlib.redirect_stderr(io.StringIO()):
            return flutter_quality.pre_push_status(
                self.root, self.updates() if updates is None else updates
            )

    def test_unrelated_dirty_design_sources_do_not_fail_generated_check(self):
        (self.root / "lib/ordinary.dart").write_text("const value = 2;\n", encoding="utf-8")
        self.assertTrue(self.check())

    def test_modified_or_staged_generated_source_fails(self):
        self.generated.write_text("const generatedValue = 2;\n", encoding="utf-8")
        self.assertFalse(self.check())
        self.git("add", "lib/example.g.dart")
        self.assertFalse(self.check())

    def test_deleted_generated_source_fails(self):
        self.generated.unlink()
        self.assertFalse(self.check())

    def test_untracked_generated_source_fails(self):
        (self.root / "lib/new.freezed.dart").write_text("// generated\n", encoding="utf-8")
        self.assertFalse(self.check())

    def test_ignored_generated_source_in_lib_still_fails(self):
        (self.root / ".gitignore").write_text("*.g.dart\n", encoding="utf-8")
        (self.root / "lib/untracked.g.dart").write_text("// generated\n", encoding="utf-8")
        self.assertFalse(self.check())

    def test_pre_push_clean_head_passes(self):
        self.assertEqual(self.push_status(), 0)

    def test_pre_push_rejects_tracked_and_staged_local_fixes(self):
        (self.root / "lib/ordinary.dart").write_text("const value = 2;\n", encoding="utf-8")
        self.assertEqual(self.push_status(), 1)
        self.git("add", "lib/ordinary.dart")
        self.assertEqual(self.push_status(), 1)

    def test_pre_push_rejects_untracked_ci_inputs(self):
        for name in (
            "lib/new.dart", "test/new_test.dart", "integration_test/new_test.dart",
            "assets/catalog.dat", "packages/plugin/lib/source.dart", "tool/check.py",
            "scripts/check.sh", ".github/workflows/quality.yml", ".githooks/pre-push",
            "supabase/functions/ai-album-draft/composition-contract.json",
            "supabase/functions/ai-album-draft/index.ts",
            "supabase/migrations/20261021000000_fixture.sql",
            "docs/spec.md", "web/index.html", "android/source.kt", "ios/source.swift",
            "linux/source.cc", "macos/source.swift", "windows/source.cpp",
            "Makefile", "pubspec.yaml", "pubspec.lock", "analysis_options.yaml",
        ):
            with self.subTest(path=name):
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("local CI input\n", encoding="utf-8")
                self.assertEqual(self.push_status(), 1)
                path.unlink()

    def test_pre_push_rejects_tracked_and_staged_supabase_contract_fixes(self):
        contract = self.root / "supabase/functions/ai-album-draft/composition-contract.json"
        contract.parent.mkdir(parents=True)
        contract.write_text('{"version": 1}\n', encoding="utf-8")
        self.git("add", "supabase")
        self.git(
            "-c", "core.hooksPath=/dev/null", "-c", "user.name=CI guard test",
            "-c", "user.email=ci-guard@example.invalid", "commit", "--quiet", "--no-gpg-sign",
            "-m", "Committed Supabase input",
        )
        self.assertEqual(self.push_status(), 0)
        contract.write_text('{"version": 2}\n', encoding="utf-8")
        self.assertEqual(self.push_status(), 1)
        self.git("add", str(contract.relative_to(self.root)))
        self.assertEqual(self.push_status(), 1)

    def test_pre_push_allows_personal_lib_and_output_edits(self):
        personal = self.root / "lib/ㅇ"
        output = self.root / "output/review.html"
        output.parent.mkdir()
        personal.write_text("personal notes\n", encoding="utf-8")
        output.write_text("review\n", encoding="utf-8")
        self.assertEqual(self.push_status(), 0)
        self.git("add", "lib/ㅇ", "output/review.html")
        self.git(
            "-c", "core.hooksPath=/dev/null", "-c", "user.name=CI guard test",
            "-c", "user.email=ci-guard@example.invalid", "commit", "--quiet", "--no-gpg-sign",
            "-m", "Existing personal files",
        )
        personal.write_text("changed personal notes\n", encoding="utf-8")
        output.write_text("changed review\n", encoding="utf-8")
        self.assertEqual(self.push_status(), 0)

    def test_pre_push_rejects_another_local_ref(self):
        self.assertEqual(self.push_status(self.updates("f" * 40)), 1)

    def test_pre_push_rejects_head_changed_since_ref_capture(self):
        original_updates = self.updates()
        (self.root / "lib/ordinary.dart").write_text("const value = 2;\n", encoding="utf-8")
        self.git("add", "lib/ordinary.dart")
        self.git(
            "-c", "core.hooksPath=/dev/null", "-c", "user.name=CI guard test",
            "-c", "user.email=ci-guard@example.invalid", "commit", "--quiet", "--no-gpg-sign",
            "-m", "Commit during checks",
        )
        self.assertEqual(self.push_status(original_updates), 1)

    def test_pre_push_rejects_malformed_ref_input(self):
        self.assertEqual(self.push_status("refs/heads/main incomplete\n"), 1)

    def test_pre_push_deletion_only_skips_checks_even_with_local_edits(self):
        head = self.git("rev-parse", "HEAD").stdout.strip()
        (self.root / "lib/ordinary.dart").write_text("const value = 2;\n", encoding="utf-8")
        deletion = f"(delete) {'0' * len(head)} refs/heads/old {head}\n"
        self.assertEqual(self.push_status(deletion), flutter_quality.NO_UPDATES_TO_CHECK)

    def test_pre_push_no_updates_skips_checks(self):
        self.assertEqual(self.push_status(""), flutter_quality.NO_UPDATES_TO_CHECK)

    def test_pre_push_mixed_head_and_deletion_checks_the_head(self):
        head = self.git("rev-parse", "HEAD").stdout.strip()
        deletion = f"(delete) {'0' * len(head)} refs/heads/old {head}\n"
        self.assertEqual(self.push_status(self.updates() + deletion), 0)
        (self.root / "lib/ordinary.dart").write_text("const value = 2;\n", encoding="utf-8")
        self.assertEqual(self.push_status(self.updates() + deletion), 1)


class SdkGuardTest(unittest.TestCase):
    def check(self, flutter="3.47.1", bundled="3.13.1", path_dart="3.13.1"):
        responses = [
            subprocess.CompletedProcess(
                [], 0,
                stdout=json.dumps({"frameworkVersion": flutter, "dartSdkVersion": bundled}),
                stderr="",
            ),
            subprocess.CompletedProcess([], 0, stdout=f"Dart SDK version: {path_dart} (stable)", stderr=""),
        ]
        with (
            patch.object(flutter_quality, "sdk_pins", return_value=("3.47.1", "3.13.1")),
            patch.object(flutter_quality.subprocess, "run", side_effect=responses),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            return flutter_quality.verify_sdk()

    def test_matching_flutter_bundled_dart_and_path_dart_pass(self):
        self.assertTrue(self.check())

    def test_floating_flutter_update_fails(self):
        self.assertFalse(self.check(flutter="3.47.7"))

    def test_mismatched_path_dart_fails(self):
        self.assertFalse(self.check(path_dart="3.13.2"))

    def test_mismatched_bundled_dart_fails(self):
        self.assertFalse(self.check(bundled="3.13.2"))


class HookInstallerTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="snapfit-hook-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.environment = isolated_git_environment()
        self.command("git", "init", "--quiet")
        (self.root / "tool").mkdir()
        (self.root / ".githooks").mkdir()
        self.installer = self.root / "tool/install_pre_push_hook.sh"
        shutil.copyfile(flutter_quality.ROOT / "tool/install_pre_push_hook.sh", self.installer)
        self.hook = self.root / ".githooks/pre-push"
        self.hook.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        self.hook.chmod(0o755)

    def command(self, *args):
        return subprocess.run(
            args, cwd=self.root, capture_output=True, text=True,
            env=self.environment,
        )

    def install(self):
        return self.command("bash", str(self.installer))

    def test_clean_install_is_local_and_idempotent(self):
        self.assertEqual(self.install().returncode, 0)
        local = self.command("git", "config", "--local", "--get", "core.hooksPath")
        self.assertEqual(local.stdout.strip(), ".githooks")
        self.assertEqual(self.install().returncode, 0)

    def test_existing_pre_push_is_not_overwritten(self):
        existing = self.root / ".git/hooks/pre-push"
        original = "#!/bin/sh\necho existing-user-hook\n"
        existing.write_text(original, encoding="utf-8")
        self.assertEqual(self.install().returncode, 1)
        self.assertEqual(existing.read_text(encoding="utf-8"), original)
        self.assertEqual(self.command("git", "config", "--get", "core.hooksPath").returncode, 1)

    def test_existing_hook_configuration_is_not_overwritten(self):
        self.assertEqual(self.command("git", "config", "--local", "core.hooksPath", "custom-hooks").returncode, 0)
        self.assertEqual(self.install().returncode, 1)
        self.assertEqual(self.command("git", "config", "--get", "core.hooksPath").stdout.strip(), "custom-hooks")

    def test_other_existing_hooks_are_not_disabled(self):
        original = "#!/bin/sh\necho existing-hook\n"
        for name, symlink in (("pre-commit", False), ("post-checkout", True)):
            with self.subTest(name=name):
                existing = self.root / ".git/hooks" / name
                if symlink:
                    target = self.root / "user-hook"
                    target.write_text(original, encoding="utf-8")
                    target.chmod(0o755)
                    existing.symlink_to(target)
                else:
                    existing.write_text(original, encoding="utf-8")
                    existing.chmod(0o755)
                self.assertEqual(self.install().returncode, 1)
                self.assertEqual(existing.read_text(encoding="utf-8"), original)
                self.assertEqual(existing.is_symlink(), symlink)
                self.assertEqual(self.command("git", "config", "--get", "core.hooksPath").returncode, 1)
                existing.unlink()


if __name__ == "__main__":
    unittest.main()
