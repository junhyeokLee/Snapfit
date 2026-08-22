# Snapfit Template Image Creative Director Guide

## Non-negotiable target

Snapfit template images must **surpass a MiriCanvas-style marketplace preview**, not merely match it. The template should look like a paid product before the user edits anything.

The visual promise is:

> “This looks like my real life, but edited by a designer.”

## Global image rule

Every template, regardless of theme, must use images that feel relatable and embedded in real life.

Required qualities:

- Human presence: backs, silhouettes, hands, partial body crops, interactions, or traces of a person just outside frame.
- Everyday context: food, coffee, tickets, bags, rooms, cars, streets, homes, toys, blankets, flowers, rings, printed photos, notes, fabrics.
- Candid believability: smartphone/photo-dump energy, natural crop, real light, imperfect but curated composition.
- Theme fit: the image must support the page role — cover, opening, route, detail, quote, timeline, contact sheet, closing — not just decorate it.
- Commercial safety: no logos, brands, readable text, celebrity likeness, recognizable faces, or copyrighted-style imitation.

Rejected images:

- Empty pretty landscapes used as the main image set.
- Generic stock photos with no personal emotion.
- AI-looking faces/hands.
- Over-polished catalog shots that users cannot imagine in their own phone.
- Random images that do not match the page's layout role.

## Generation workflow

1. **Write one product brief per template**
   - audience/use case
   - emotional promise
   - cover shot
   - 6–8 page-role shots
   - motifs and palette

2. **Generate image sets, not isolated images**
   - Cover, opening, detail, human moment, object detail, closing image should feel like the same story.
   - Keep lighting, palette, season, and camera feeling consistent.

3. **Map image to page role before inserting**
   - Cover: immediate desire / user clicks it.
   - Opening: sets emotional scene.
   - Detail: hands, food, objects, room, ticket, flower, ring, toy.
   - Story page: people from behind, motion, interaction.
   - Quote/closing: quiet emotional image with space for typography.

4. **Human-review every generated image**
   - Reject if it contains visible logo/text/brand.
   - Reject if faces are identifiable.
   - Reject if hands or bodies look uncanny.
   - Reject if it is just scenery.
   - Reject if it does not make the template more desirable.

5. **Record provenance**
   - provider/model
   - generation timestamp
   - prompt
   - job id/seed if available
   - status: `generated-needs-human-review`, then `approved-ai-generated`


## Reference-board policy

Pinterest, MiriCanvas, Canva, Instagram, portfolio, magazine, album cover, and photobook examples may be used to study mood, composition, hierarchy, motif discipline, and user desire. They must not be copied directly and must never become bundled assets.

When using references, record the interpreted design lesson rather than the source image itself, e.g. “large quiet couple back-view with title in safe sky area,” “hands arranging printed photos as cover desire,” or “baby detail closeup with parent hand for emotional safety.”

## Per-template image direction

The machine-readable brief lives at:

```text
assets/templates/_art_direction/template_image_briefs.json
```

Use that file when generating or reviewing GPT image sets for every template.

## Template-specific creative rules

### 제주의 기록
People's travel traces first; Jeju scenery second. Airport, car window, cafe table, beach backs, market hands, guesthouse luggage, sunset silhouettes, photo-dump flatlay.

### Wedding Editorial
Intimate wedding details and candid back-view/hand/veil moments. Avoid stiff studio poses. Cream/gold editorial consistency.

### SAVE THE DATE
Date announcement should feel premium and personal: hands, card, flowers, rings, fabric, couple shadows, venue context.

### 소프트 베이비북
Soft family/baby detail, not uncanny full baby faces. Hands/feet, parent hands, blanket, toys, nursery, milestone objects.

### 가족의 주말
Ordinary warm weekend: picnic, snacks, child hands, living room, dining table, park walk, real family messiness.

### 필름 다이어리
Analog photo-dump: hands, film camera, printed photos, friends from behind, street/cafe/night window, tape/diary objects.

### 화이트 에디토리얼
Minimal lifestyle with real human trace: room/window/cafe, hands arranging objects, fabric/books/flowers, whitespace.

### 우리의 기념일
Everyday couple intimacy: cake, hands, flowers, restaurant table, street back-view, gift/letter detail, window silhouette.

### Scrapbook
Messy-curated memory board: hands arranging prints, tape, blank receipts, coffee, friends back-view, diary objects.


## Layout + image integration source of truth

Image generation alone is not enough. For crop, position, decoration, typography, and page-role rules, use:

- `docs/SNAPFIT_TEMPLATE_LAYOUT_CREATIVE_DIRECTOR.md`

## Final acceptance bar

A template image set is good enough only if:

- Users can imagine they have similar photos in their phone.
- The cover creates immediate desire.
- Each inner page image naturally fits its role.
- The full set feels like one complete product story.
- The template would still look premium after users replace the sample images with their own.
