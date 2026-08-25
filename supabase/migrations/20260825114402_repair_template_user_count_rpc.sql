-- Repair template user-count RPC under a unique migration timestamp.
-- The original local file reused 20260825030000, which conflicted with another
-- migration and could be skipped or block future db push runs.

CREATE OR REPLACE FUNCTION public.increment_template_user_count(p_template_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.templates
     SET user_count = user_count + 1
   WHERE id = p_template_id;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_template_user_count(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.increment_template_user_count(bigint) FROM anon;
GRANT EXECUTE ON FUNCTION public.increment_template_user_count(bigint) TO authenticated;
