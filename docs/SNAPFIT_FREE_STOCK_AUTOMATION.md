# Snapfit Free Stock Image Automation

Use this path when GPT/API image generation is unavailable or too expensive and the user wants Hermes to source images directly from free/commercial-use image sites.

## Default no-key source: Openverse

`tool/source_template_images_openverse.py` searches Openverse for images marked for commercial use and downloads candidates with provenance metadata.

```bash
python3 tool/source_template_images_openverse.py --template jeju_travel_v1 --per-role 2
```

All templates:

```bash
python3 tool/source_template_images_openverse.py --template all --per-role 2
```

Dry run without downloads:

```bash
python3 tool/source_template_images_openverse.py --template jeju_travel_v1 --dry-run
```

## Important limitation

This is automated sourcing, not automatic approval.

Openverse can return CC BY images that require attribution, and commercial-use filters do not prove model/property releases. Before inserting images into app templates, review each candidate for:

- license and attribution requirements
- no readable text/logo/brand
- no identifiable faces unless release status is verified
- no uncanny or low-quality image content
- fit with the template page role and emotional direction

## Preferred production flow

1. Run the sourcing script.
2. Visually review candidate contact sheets.
3. Select approved images.
4. Copy approved images into the template's production image directory.
5. Update `*_sources.md` with exact provider/license/attribution metadata.
6. Wire selected images into `store_latest.json`, generated store JSON, and handoff JSON.
7. Run template checks and Flutter checks.

## Better relevance option

For better lifestyle/travel/wedding/family search relevance, use a free Pexels or Pixabay developer API key later. Those keys are not ChatGPT/OpenAI keys and can be free, but they still require account setup and license review.

## Higher-quality free source: Pexels API

For better lifestyle/travel/wedding/family relevance, use Pexels. This requires a free API key but does not require OpenAI/API image-generation billing.

1. Create a free Pexels API key at https://www.pexels.com/api/
2. In the VPS/container shell:

```bash
cd /srv/projects/Snapfit
export PEXELS_API_KEY="your_pexels_key"
python3 tool/source_template_images_pexels.py --template jeju_travel_v1 --per-role 2
```

Dry run:

```bash
python3 tool/source_template_images_pexels.py --template jeju_travel_v1 --dry-run
```

The script saves images under:

```text
assets/templates/<template_slug>/images/pexels_candidates/
```

Then Hermes can review candidates, select the best images, wire them into the template JSON, and update source records.
