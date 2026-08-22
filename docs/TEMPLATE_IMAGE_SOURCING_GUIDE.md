# Snapfit Template Image Sourcing Guide

Snapfit's template store should feel like a paid design catalog. The example images are part of the product, because users judge the template before they edit anything.

## Product principle

Template quality is evaluated in this order:

1. Cover image sells the template at thumbnail size.
2. Photos look better inside the template than outside it.
3. The image set matches the template concept.
4. The layout has designer-level hierarchy and detail.
5. Licensing is safe for commercial app distribution.


## Relatable real-life image rule — applies to every template

All Snapfit template sample images must feel like real people actually lived the moment. The goal is not generic pretty stock, but images users emotionally recognize and want to replace with their own memories.

Required qualities across every template:

- Show human presence: back views, silhouettes, hands, partial body crops, family/couple/friend interactions, or traces of a person just outside frame.
- Show everyday context: cafe tables, food, tickets, bags, rooms, cars, streets, homes, toys, printed photos, notes, flowers, rings, blankets, or other objects people actually photograph.
- Make the scene feel personally taken: smartphone snapshot energy, candid framing, natural light, believable crop, slight lived-in imperfection, not sterile catalog photography.
- Use scenery as context, not the whole subject. For travel, ocean/mountain/sunset should support a human travel memory, not become a scenery-only wallpaper.
- Avoid generic empty landscapes, abstract filler, over-polished AI faces, brand signage, readable text, logos, celebrity likeness, or images that feel detached from real life.

Template acceptance rule: if a user cannot imagine “I have a photo like this in my phone,” the image set is not good enough for a paid Snapfit template.

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

1. Arrival/travel hero with people from behind, a hand, luggage, ticket, or car/window context; scenery supports the human memory.
2. Road/route or walking path image with a companion, hand-held drink, phone, bag, or other lived-in travel trace.
3. Cafe/window detail image.
4. Ticket/postcard/hand detail image.
5. Oreum/hill or wide landscape image with human scale, silhouette, walking path, or traveler object in frame.
6. Sunset/silhouette closing image with couple/friends/family from behind or someone taking a photo.
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

1. Couple portrait or back-view hero that feels candid and personal, not a sterile stock pose.
2. Ceremony wide shot with real guest/table/flower/context details, not an empty venue render.
3. Bouquet detail.
4. Rings/detail object.
5. Hands/veil close-up.
6. Bride/groom diptych images.
7. Cream table or stationery detail.
8. Closing romantic image with hands, backs, veil movement, or a quiet human moment.

Design details:

- Cream/brown/gold palette.
- Serif editorial headline.
- Thin rule lines.
- Invitation card page.
- Arch photo masks.

### Save the Date

Must sell quickly at thumbnail size.

Required image set:

1. Couple hero with candid interaction, back view, hands, or natural pre-wedding moment.
2. Date/stationery detail with flowers, hands, fabric, coffee/table context, and no readable private text.
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

1. Family backs/walk/picnic hero with ordinary warmth: bags, blanket, snacks, hands, child movement, or home/park context.
2. Child hands or play detail.
3. Dining table/home detail that looks lived-in: plates, cups, drawings, toys, hands, soft messiness.
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

1. Baby hands/feet hero with blanket, parent hand, toy, or room context; avoid uncanny AI baby faces.
2. Blanket/toy detail with real nursery/home traces such as folded clothes, books, milestone card, or parent hand.
3. Parent hands detail.
4. Milestone card image.
5. Birthday or monthly marker.
6. Closing parent-message image.

Design details:

- Pastel pink/blue/cream.
- Milestone labels.
- Parent message page.
- Avoid large uncanny AI faces.


## Creative director source of truth

For per-template GPT image generation briefs and the “real life, designer edited” standard, use:

- `docs/SNAPFIT_TEMPLATE_IMAGE_CREATIVE_DIRECTOR.md`
- `assets/templates/_art_direction/template_image_briefs.json`

## Release gate

Before a template is considered store-grade:

- `template_quality_check.py` passes.
- Every production image has a source record in `assets/templates/_licenses/`.
- No bundled preview image uses a prohibited source.
- Cover thumbnail reads clearly at small size.
- At least 6 pages have distinct design purposes.
- The template can be described in one sentence as a paid product.
