# Snapfit Template Image Sourcing Guide

Snapfit's template store should feel like a paid design catalog. The example images are part of the product, because users judge the template before they edit anything.

## Product principle

Template quality is evaluated in this order:

1. Cover image sells the template at thumbnail size.
2. Photos look better inside the template than outside it.
3. The image set matches the template concept.
4. The layout has designer-level hierarchy and detail.
5. Licensing is safe for commercial app distribution.

## Do not use directly

These can be used as mood references only, never as bundled template images:

- Pinterest pins
- MiriCanvas/Canva templates or preview images
- Instagram posts
- Portfolio/agency images
- Blog images
- Google Images results
- Brand/editorial campaign images

## Approved sourcing paths

### Best: Snapfit-owned shoots

Use for hero templates that define the app brand.

Recommended shoots:

- Jeju travel: ocean, road, cafe window, ticket hand, sunset silhouette.
- Wedding: couple backs, bouquet, rings, veil, hands, cream-tone table details.
- Family weekend: picnic, child hands, family backs, dining table, park walk.
- Babybook: baby hands/feet, blanket, toy, milestone card, soft family scene.
- Scrapbook/film: cafe, street, printed photos, desk, tape, diary details.

### Good: paid stock

Use when a shoot is not available yet. Archive receipts/license pages under a private ops folder and record the public-safe metadata here.

Recommended providers:

- Adobe Stock
- Shutterstock
- Envato Elements
- Freepik Premium, only when the selected license allows app/template previews

### Acceptable for early production: free commercial stock

Use carefully. Prefer non-famous, less-used imagery and avoid recognizable faces unless the license and release status are clear.

Candidate providers:

- Pexels
- Unsplash
- Pixabay
- Kaboompics

### Acceptable with review: AI-generated imagery

Useful for consistent brand direction, but avoid uncanny faces/hands and any copyrighted style imitation.

Rules:

- Prefer back views, hands, silhouettes, objects, landscapes, and shallow-focus details.
- Avoid celebrity-like people and brand logos.
- Keep prompt, seed/job id, provider, and terms snapshot.
- Human-review every image before app release.

## Per-template image shot lists

### Jeju Travel / 제주의 기록

Must feel like a travel magazine.

Required image set:

1. Full-bleed ocean or coastal hero image.
2. Road/route or walking path image.
3. Cafe/window detail image.
4. Ticket/postcard/hand detail image.
5. Oreum/hill or wide landscape image.
6. Sunset/silhouette closing image.
7. Optional food/table detail.
8. Optional map-like object/detail.

Design details:

- Route dots and line.
- Day labels.
- Location captions.
- Postcard/ticket card pages.
- Sea/sand/navy/coral palette.

### Wedding Editorial

Must feel like a paid wedding photo-book/invitation template.

Required image set:

1. Couple portrait or back-view hero.
2. Ceremony wide shot.
3. Bouquet detail.
4. Rings/detail object.
5. Hands/veil close-up.
6. Bride/groom diptych images.
7. Cream table or stationery detail.
8. Closing romantic image.

Design details:

- Cream/brown/gold palette.
- Serif editorial headline.
- Thin rule lines.
- Invitation card page.
- Arch photo masks.

### Save the Date

Must sell quickly at thumbnail size.

Required image set:

1. Couple hero.
2. Date/stationery detail.
3. Flower/fabric detail.
4. Ring or hand detail.
5. Venue/ceremony wide shot.
6. Closing quote image.

Design details:

- Date is the focal point.
- High contrast but soft.
- Minimal, premium typography.

### Family Weekend

Must feel warm, approachable, and emotionally useful.

Required image set:

1. Family backs/walk/picnic hero.
2. Child hands or play detail.
3. Dining table/home detail.
4. Park/walk outdoor image.
5. Parent-child close detail.
6. Closing group/silhouette image.

Design details:

- Warm paper palette.
- Handwritten-style notes if licensed font permits.
- Date stamp / today note / checklist pages.

### Soft Babybook

Must feel soft, safe, and giftable.

Required image set:

1. Baby hands/feet hero.
2. Blanket/toy detail.
3. Parent hands detail.
4. Milestone card image.
5. Birthday or monthly marker.
6. Closing parent-message image.

Design details:

- Pastel pink/blue/cream.
- Milestone labels.
- Parent message page.
- Avoid large uncanny AI faces.

## Release gate

Before a template is considered store-grade:

- `template_quality_check.py` passes.
- Every production image has a source record in `assets/templates/_licenses/`.
- No bundled preview image uses a prohibited source.
- Cover thumbnail reads clearly at small size.
- At least 6 pages have distinct design purposes.
- The template can be described in one sentence as a paid product.
