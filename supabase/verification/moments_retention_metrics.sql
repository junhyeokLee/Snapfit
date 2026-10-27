-- Administrator-only, read-only aggregate. No photos, notes or user identifiers
-- are returned. Journal creation is actual server save time even for backdates;
-- empty deletion tombstones keep the first-save denominator stable. Activity is
-- retained 90 days, so cohorts older than 90 days are intentionally excluded.
-- D7–D13 return needs 14 complete observation days; monthly conversion needs 30.
with first_saves as (
 select owner_id,min(created_at) first_saved_at
 from moments_private.weekly_moments group by owner_id
), eligible as (
 select f.*,date_trunc('week',f.first_saved_at at time zone 'Asia/Seoul')::date cohort_week
 from first_saves f where first_saved_at>=moments_private.server_now()-interval '90 days'
), outcomes as (
 select e.*,
  e.first_saved_at+interval '14 days'<=moments_private.server_now() observed_week_one,
  e.first_saved_at+interval '30 days'<=moments_private.server_now() observed_month,
  exists(select 1 from moments_private.activity a where a.owner_id=e.owner_id
   and a.event in('record_saved','recap_viewed') and a.occurred_at>=e.first_saved_at+interval '7 days'
   and a.occurred_at<e.first_saved_at+interval '14 days') returned_week_one,
  exists(select 1 from moments_private.activity a where a.owner_id=e.owner_id
   and a.event='album_created' and a.occurred_at>=e.first_saved_at
   and a.occurred_at<e.first_saved_at+interval '30 days') created_month_album
 from eligible e
)
select cohort_week,count(*)::integer first_savers,
 count(*)filter(where observed_week_one)::integer week_one_observed_users,
 count(*)filter(where observed_week_one and returned_week_one)::integer week_one_returned_users,
 round(100.0*count(*)filter(where observed_week_one and returned_week_one)/nullif(count(*)filter(where observed_week_one),0),1) week_one_return_percent,
 count(*)filter(where observed_month)::integer month_observed_users,
 count(*)filter(where observed_month and created_month_album)::integer month_album_creators,
 round(100.0*count(*)filter(where observed_month and created_month_album)/nullif(count(*)filter(where observed_month),0),1) month_album_conversion_percent
from outcomes group by cohort_week order by cohort_week desc;
