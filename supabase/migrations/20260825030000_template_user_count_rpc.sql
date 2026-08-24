-- Authenticated users cannot directly UPDATE templates (admin-only write policy).
-- Provide a SECURITY DEFINER RPC so the client can increment user_count without
-- bypassing the admin write restriction for other columns.

CREATE OR REPLACE FUNCTION public.increment_template_user_count(p_template_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.templates
     SET user_count = user_count + 1
   WHERE id = p_template_id;
END;
$$;

-- Only authenticated users may call this function.
REVOKE ALL ON FUNCTION public.increment_template_user_count(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_template_user_count(bigint) TO authenticated;
