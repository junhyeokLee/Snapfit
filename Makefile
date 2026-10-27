.PHONY: template-release template-release-dry template-gate ci-check ci-generated install-pre-push

# The same pinned SDK, generation, formatting, analysis, audits and one full
# Flutter test run as CI. Regenerated sources must be reviewed and committed.
ci-check:
	bash scripts/check_flutter_quality.sh all

ci-generated:
	bash scripts/check_flutter_quality.sh generated

# Optional. Preserves an existing hooksPath and every non-sample hook.
install-pre-push:
	bash tool/install_pre_push_hook.sh

# Usage:
# make template-release HANDOFF=/path/to/new_handoff.json PAGES=12 SUPABASE_URL=https://your-project.supabase.co
# make template-release-dry HANDOFF=/path/to/new_handoff.json PAGES=12

HANDOFF ?=
PAGES ?= 12
SUPABASE_URL ?= https://rrbhxdtriummqpztpjrk.supabase.co

TEMPLATE_PIPELINE = ./scripts/run_figma_template_pipeline.sh --handoff="$(HANDOFF)" --pages=$(PAGES) --supabase-url=$(SUPABASE_URL)

template-release:
	$(TEMPLATE_PIPELINE) --publish=true --notify=false

template-release-dry:
	$(TEMPLATE_PIPELINE) --publish=false --notify=false

template-gate:
	@test -n "$(HANDOFF)" || { echo 'HANDOFF=/path/to/new_handoff.json is required.' >&2; exit 2; }
	dart run tool/build_store_templates_from_handoff.dart --input="$(HANDOFF)" --output=assets/templates/generated/store_latest.json --pages=$(PAGES)
	dart run tool/template_release_gate.dart --store-json=assets/templates/generated/store_latest.json
