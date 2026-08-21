.PHONY: template-release template-release-dry template-gate

# Usage:
# make template-release HANDOFF=assets/templates/save_the_date_handoff.json PAGES=12 SUPABASE_URL=https://rrbhxdtriummqpztpjrk.supabase.co
# make template-release-dry HANDOFF=assets/templates/save_the_date_handoff.json PAGES=12

HANDOFF ?= assets/templates/save_the_date_handoff.json
PAGES ?= 12
SUPABASE_URL ?= https://rrbhxdtriummqpztpjrk.supabase.co

TEMPLATE_PIPELINE = ./scripts/run_figma_template_pipeline.sh --handoff=$(HANDOFF) --pages=$(PAGES) --supabase-url=$(SUPABASE_URL)

template-release:
	$(TEMPLATE_PIPELINE) --publish=true --notify=false

template-release-dry:
	$(TEMPLATE_PIPELINE) --publish=false --notify=false

template-gate:
	dart run tool/build_store_templates_from_handoff.dart --input=$(HANDOFF) --output=assets/templates/generated/store_latest.json --pages=$(PAGES)
	dart run tool/template_release_gate.dart --store-json=assets/templates/generated/store_latest.json
