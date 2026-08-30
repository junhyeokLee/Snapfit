# Supabase template asset migration inventory

Status: partial migration guardrail. Do not replace template image URLs until the matching assets are uploaded and verified in Supabase Storage.

## Current finding

`lib/features/store/data/api/template_provider.dart` still contains Firebase Storage fallback URLs for hardcoded/local template data. These URLs are visual/template assets, so replacing them blindly can break store cards, template detail pages, or generated album pages.

## Safe migration order

1. Upload the matching template assets to a Supabase Storage bucket dedicated to public template assets.
2. Record a one-to-one mapping from each legacy Firebase URL/object to its Supabase public URL or signed resolver URI.
3. Update seed data and local fallback data together.
4. Run store/template widget tests and visually inspect template cards/detail pages.
5. Only then remove the Firebase Storage fallback URLs.

## Guardrail

Until step 2 is complete, keep the existing fallback URLs rather than substituting guessed URLs. This preserves the current main/read/template visual baseline.
