-- Add user_count and like_count to templates.
-- user_count: how many users applied this template to an album.
-- like_count: maintained by trigger on template_likes insert/delete.

ALTER TABLE public.templates
  ADD COLUMN IF NOT EXISTS user_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS like_count integer NOT NULL DEFAULT 0;

-- Trigger function: keep like_count in sync with template_likes rows.
CREATE OR REPLACE FUNCTION public.sync_template_like_count()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.templates
       SET like_count = like_count + 1
     WHERE id = NEW.template_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.templates
       SET like_count = GREATEST(0, like_count - 1)
     WHERE id = OLD.template_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_template_like_count ON public.template_likes;
CREATE TRIGGER trg_template_like_count
  AFTER INSERT OR DELETE ON public.template_likes
  FOR EACH ROW EXECUTE FUNCTION public.sync_template_like_count();

-- Back-fill like_count from existing rows (if any).
UPDATE public.templates t
   SET like_count = (
     SELECT COUNT(*) FROM public.template_likes tl WHERE tl.template_id = t.id
   );
