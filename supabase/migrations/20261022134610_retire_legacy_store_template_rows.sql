-- Retire only the nine verified legacy catalog rows. Existing album snapshots,
-- current published products, ownership, point ledgers and image assets remain
-- unchanged. template_likes is the only templates foreign key and cascades.
-- Re-running this data-only cleanup is safe, including after manual retirement.
DELETE FROM public.templates AS catalog
USING (VALUES
  (46::bigint, '제주의 기록'),
  (48::bigint, '가족의 주말'),
  (49::bigint, '우리의 기념일'),
  (50::bigint, 'Wedding Editorial'),
  (51::bigint, 'Scrapbook'),
  (52::bigint, 'SAVE THE DATE'),
  (53::bigint, '화이트 에디토리얼'),
  (54::bigint, '필름 다이어리'),
  (55::bigint, '소프트 베이비북')
) AS retired(id, title)
WHERE catalog.id = retired.id
  AND catalog.title = retired.title;
