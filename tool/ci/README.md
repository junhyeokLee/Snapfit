# Flutter quality checks

Run `make ci-check` before pushing. This runs the same checks as GitHub CI:

1. Verify Flutter 3.47.1 and both its bundled and PATH Dart 3.13.1.
2. Install dependencies with the committed lockfile enforced.
3. Run `build_runner`, then regenerate both standalone AI contracts.
4. Verify formatting, contract freshness, and committed generated Dart sources.
5. Run analysis, the CI guard tests, both existing audits, and the full Flutter
   suite once with `--concurrency=2` in both CI and local checks.

The SDK versions come from `tool/print_fulfillment/linux/runtime-pins.json` so
the production renderer, CI and local checks share the same version pins.

`make ci-generated` runs only regeneration and its checks after dependencies
have been installed. Regeneration updates generated files; review and commit
their changes. The generated-source check includes staged changes, deletions,
new untracked files, and ignored generated sources under `lib/` or `test/`.
Unrelated local design edits do not fail that check.

Use `make install-pre-push` to opt in to the checked-in `.githooks/pre-push`.
The installer only changes this repository's local `core.hooksPath`, and
refuses to replace an existing hooks path or disable any non-sample hook file
or symlink in the existing hooks directory. Existing hook
users can call `make ci-check` from their own hook instead.

The pre-push hook additionally requires committed CI inputs and checks that
every non-deletion ref update points to the checked-out `HEAD`, before and
after the quality run. Tracked, staged and untracked source/config changes
are rejected so uncommitted local fixes cannot conceal a failing pushed commit.
The guard covers Dart under `lib/`, plus tests, assets, packages, tools,
scripts, workflows, documentation, platform sources and build configuration.
`output/` and non-Dart personal files under `lib/` are outside that scope.
Deletion-only pushes need no SDK run. `make ci-check` itself remains available
during normal editing; the commit/ref guard belongs only to the hook.

`ci.yml` is the single automatic GitHub entry point. It calls the reusable
`flutter-ci.yml`; the latter is also available for an explicit manual run.
