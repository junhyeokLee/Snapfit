-- Templates with negative IDs cannot be liked because the client-side guard
-- treats id < 0 as "not yet connected to the server". Reassign them to proper
-- positive IDs so the like flow works for all templates.
--
-- ID mapping:
--   -1115056 (SAVE THE DATE)    → 52
--   -8006    (화이트 에디토리얼) → 53
--   -8007    (필름 다이어리)    → 54
--   -8008    (소프트 베이비북)  → 55

-- Move any existing likes first to avoid FK violations during the ID update.
UPDATE public.template_likes SET template_id = 52 WHERE template_id = -1115056;
UPDATE public.template_likes SET template_id = 53 WHERE template_id = -8006;
UPDATE public.template_likes SET template_id = 54 WHERE template_id = -8007;
UPDATE public.template_likes SET template_id = 55 WHERE template_id = -8008;

UPDATE public.templates SET id = 52 WHERE id = -1115056;
UPDATE public.templates SET id = 53 WHERE id = -8006;
UPDATE public.templates SET id = 54 WHERE id = -8007;
UPDATE public.templates SET id = 55 WHERE id = -8008;

-- Advance the identity sequence past all assigned IDs.
SELECT setval(
  pg_get_serial_sequence('public.templates', 'id'),
  GREATEST(100, (SELECT COALESCE(MAX(id), 0) FROM public.templates WHERE id > 0))
);
