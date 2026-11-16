-- A moderated owner's management row remains usable without releasing an image
-- capability or Storage path. Other viewers must never receive this placeholder.
create or replace function social_private.social_work_json(p_id uuid)returns jsonb
language sql stable set search_path='' as $$
 with work as materialized(
  select w.*,social_private.work_restricted(w.id)is_restricted
  from public.social_works w where w.id=p_id
 )
 select jsonb_build_object('id',w.id,'author',social_private.social_profile_json(w.author_id),
  'title',w.title,'caption',w.caption,'topic',w.topic,'status',w.status,'aspectRatio',w.aspect_ratio,
  'kind',w.kind,'recordDate',w.record_date,'createdAt',coalesce(w.published_at,w.created_at),
  'isRestricted',w.is_restricted,
  'imagePaths',case when w.is_restricted then '[]'::jsonb else
   coalesce((select jsonb_agg(p.storage_path order by p.position)from public.social_work_pages p where p.work_id=w.id),'[]'::jsonb)end,
  'mediaVersion',2,'mediaTokens',case when w.is_restricted then '[]'::jsonb else social_private.media_tokens(w.id)end,
  'likeCount',(select count(*)from public.social_likes l where l.work_id=w.id),
  'commentCount',(select count(*)from public.social_comments c where c.work_id=w.id and not c.moderation_hidden and not social_private.social_blocked(c.author_id)),
  'isLiked',exists(select 1 from public.social_likes l where l.work_id=w.id and l.user_id=auth.uid()),
  'isSaved',exists(select 1 from public.social_saves s where s.work_id=w.id and s.user_id=auth.uid()),
  'sourceTemplate',case when w.kind='album'and not w.is_restricted then social_private.work_template_source(w.id)else null end,
  'publicationRevision',case when w.kind='moment'and w.author_id=auth.uid()then(select s.revision from moments_private.publications s join social_private.moment_publication_sources b on b.record_id=s.record_id where b.work_id=w.id and s.current_work_id=w.id)else null end)
 from work w where not w.is_restricted or w.author_id=auth.uid()
$$;
revoke all on function social_private.social_work_json(uuid)from public,anon,authenticated,service_role;
