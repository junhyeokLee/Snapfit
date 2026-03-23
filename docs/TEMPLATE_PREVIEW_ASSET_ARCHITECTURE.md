# Template Preview Asset Architecture

This document describes the recommended production structure for template preview assets.

## Goal
- Keep template layout logic and preview media assets separated.
- Make list rendering fast (`thumb` only).
- Allow operations teams to swap preview media without app redeploy.

## Metadata Fields
Each `DesignTemplate` supports:
- `previewThumbUrl`: lightweight card thumbnail (list/grid).
- `previewDetailUrl`: larger image for detail modal/screen.
- `previewImageUrls[]`: slot-level sample images for template apply/preview.

When server payload does not provide these fields, the app hydrates fallback values by `template.id`.

## Runtime Rules
1. Template list card renders only `previewThumbUrl`.
2. Detail page uses `previewDetailUrl`.
3. Template apply/sample slot injection uses `previewImageUrls[]`.
4. If all media fields are missing, app uses deterministic fallback by template id.

## Caching Strategy
- Card list preloads top 8 thumbnail URLs after first frame.
- Network image uses cache-aware widget (`SnapfitImage` / `CachedNetworkImage` path).

## Backend Contract (Recommended)
`GET /api/design-templates` item fields:
- `id`, `name`, `aspect`, `category`, `tags`, `style`, `difficulty`, ...
- `previewThumbUrl` (string)
- `previewDetailUrl` (string)
- `previewImageUrls` (string array)

## Operational Notes
- Keep preview assets in CDN/S3.
- Use versioned path (`.../templates/{id}/v{n}/thumb.webp`) for safe cache busting.
- Maintain license/source table for every preview asset.
