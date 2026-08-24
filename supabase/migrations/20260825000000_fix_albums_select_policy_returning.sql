-- Fix: INSERT ... RETURNING fails with 42501 because the SELECT policy (USING)
-- evaluates can_access_album() which queries the albums table using the INSERT
-- statement's snapshot — the newly inserted row isn't visible yet, so it returns
-- false, making PostgreSQL reject the RETURNING clause with an RLS violation.
--
-- Fix: add owner_id = auth.uid() as a direct column comparison (no sub-query,
-- always visible during RETURNING) so the owner can always read their own row.

DROP POLICY IF EXISTS "albums_read_member_or_admin" ON public.albums;
CREATE POLICY "albums_read_member_or_admin" ON public.albums FOR SELECT TO authenticated
USING (owner_id = auth.uid() OR public.can_access_album(id) OR public.is_admin());
