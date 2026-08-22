# Snapfit Template Image Licensing

Snapfit templates are product assets. Example/template images must be treated as commercial design material, not throwaway placeholders.

## Rules

1. Do not use Pinterest, MiriCanvas, Canva templates, Instagram, blogs, or portfolio images directly in the app.
2. Reference boards are allowed for mood, layout, palette, and composition only.
3. Production preview images must come from one of these approved sources:
   - Snapfit-owned photography or commissioned shoots.
   - Paid stock with a license that allows app/template preview use.
   - Free stock only when the license allows commercial app use and model/property rights are acceptable.
   - AI-generated images only when the provider terms allow commercial use and the image passes quality review.
4. Keep provenance for every production preview image.
5. Avoid visible third-party logos, copyrighted artworks, identifiable private locations without release, and recognizable people without model-release coverage.

## Image source status labels

- `approved-owned`: Snapfit owns or commissioned the image.
- `approved-paid-stock`: paid stock license verified and archived.
- `approved-free-stock`: free commercial license verified and archived.
- `approved-ai-generated`: AI provider commercial terms verified and generation metadata archived.
- `needs-replacement`: temporary/legacy image; must be replaced before store-grade release.
- `reference-only`: used for inspiration only; must never be bundled into the app.

## Minimum record per image

| Field | Meaning |
|---|---|
| Template | Template slug/id |
| Asset path | Local path or storage path used by the app |
| Source type | One of the status labels above |
| Source URL / prompt id | URL, stock asset ID, shoot folder, or AI job ID |
| Author / provider | Photographer, stock provider, or AI provider |
| License | License name and permitted usage |
| Model/property release | Required for people/private properties |
| Notes | Any restrictions or replacement plan |
