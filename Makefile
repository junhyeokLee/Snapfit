.PHONY: template-release template-release-dry template-gate

# Usage:
# make template-release HANDOFF=assets/templates/figma_handoff_example.json PAGES=12 BASE_URL=http://54.253.3.176
# make template-release-dry HANDOFF=assets/templates/figma_handoff_example.json PAGES=12

HANDOFF ?= assets/templates/figma_handoff_example.json
PAGES ?= 12
BASE_URL ?= http://54.253.3.176

TEMPLATE_PIPELINE = ./scripts/run_figma_template_pipeline.sh --handoff=$(HANDOFF) --pages=$(PAGES) --base-url=$(BASE_URL)

template-release:
	$(TEMPLATE_PIPELINE) --publish=true --notify=false

template-release-dry:
	$(TEMPLATE_PIPELINE) --publish=false --notify=false

template-gate:
	dart run tool/build_store_templates_from_handoff.dart --input=$(HANDOFF) --output=assets/templates/generated/store_latest.json --pages=$(PAGES)
	dart run tool/template_release_gate.dart --store-json=assets/templates/generated/store_latest.json
