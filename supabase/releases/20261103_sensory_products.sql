-- Register only these 18 delivered products. This never changes wallets,
-- ownership, customer albums or the prices/flags of any other catalog row.
begin;
set local lock_timeout='2s';
set local statement_timeout='10s';
do $sensory_release$
declare
  expected constant jsonb := $catalog_rows$[{"product_key": "frame:cafeGlassine", "asset_id": "cafeGlassine", "kind": "frame", "title": "글라신 포토 포켓", "point_price": 0, "is_active": true}, {"product_key": "frame:cafeLedgerMat", "asset_id": "cafeLedgerMat", "kind": "frame", "title": "카페 제본 매트", "point_price": 0, "is_active": true}, {"product_key": "frame:cafeReceiptFold", "asset_id": "cafeReceiptFold", "kind": "frame", "title": "영수증 접지 프레임", "point_price": 0, "is_active": true}, {"product_key": "frame:nocturneContact", "asset_id": "nocturneContact", "kind": "frame", "title": "야간 콘택트 시트", "point_price": 0, "is_active": true}, {"product_key": "frame:nocturneDuplex", "asset_id": "nocturneDuplex", "kind": "frame", "title": "듀플렉스 아카이브", "point_price": 400, "is_active": true}, {"product_key": "frame:nocturneTransit", "asset_id": "nocturneTransit", "kind": "frame", "title": "환승 티켓 마운트", "point_price": 300, "is_active": true}, {"product_key": "phrase:collage-sensory-coffee-note", "asset_id": "collage-sensory-coffee-note", "kind": "phrase", "title": "손으로 적는 카페 메모", "point_price": 0, "is_active": true}, {"product_key": "phrase:collage-sensory-night-index", "asset_id": "collage-sensory-night-index", "kind": "phrase", "title": "야간 노선 색인 문구", "point_price": 300, "is_active": true}, {"product_key": "phrase:collage-story-coffee-notebook", "asset_id": "collage-story-coffee-notebook", "kind": "phrase", "title": "오후 한 잔 타이틀", "point_price": 0, "is_active": true}, {"product_key": "phrase:collage-story-night-city-archive", "asset_id": "collage-story-night-city-archive", "kind": "phrase", "title": "도시 수집 타이틀", "point_price": 300, "is_active": true}, {"product_key": "sticker:cafeRoastedLeaf", "asset_id": "cafeRoastedLeaf", "kind": "sticker", "title": "커피나무 압화", "point_price": 0, "is_active": true}, {"product_key": "sticker:nocturneGlassine", "asset_id": "nocturneGlassine", "kind": "sticker", "title": "접힌 코발트 글라신", "point_price": 200, "is_active": true}, {"product_key": "sticker:story-coffee-notebook-motif", "asset_id": "story-coffee-notebook-motif", "kind": "sticker", "title": "황동 클립과 작은 종이", "point_price": 0, "is_active": true}, {"product_key": "sticker:story-coffee-notebook-paper", "asset_id": "story-coffee-notebook-paper", "kind": "sticker", "title": "한 잔의 기록지", "point_price": 0, "is_active": true}, {"product_key": "sticker:story-night-city-archive-motif", "asset_id": "story-night-city-archive-motif", "kind": "sticker", "title": "은박 궤도 실링", "point_price": 200, "is_active": true}, {"product_key": "sticker:story-night-city-archive-paper", "asset_id": "story-night-city-archive-paper", "kind": "sticker", "title": "야간 노선 아카이브 카드", "point_price": 100, "is_active": true}, {"product_key": "template:story-coffee-notebook", "asset_id": "story-coffee-notebook", "kind": "template", "title": "커피가 식기 전에", "point_price": 0, "is_active": true}, {"product_key": "template:story-night-city-archive", "asset_id": "story-night-city-archive", "kind": "template", "title": "밤의 도시 수집", "point_price": 1800, "is_active": true}]$catalog_rows$::jsonb;
  keys text[];
  before_hash text;
  after_hash text;
begin
  select array_agg(r.product_key) into keys from jsonb_to_recordset(expected) as r(product_key text);
  if cardinality(keys)<>18 then raise exception 'sensory_release_inventory_mismatch';end if;
  select md5(coalesce(jsonb_agg(to_jsonb(p) order by p.product_key)::text,'[]')) into before_hash
    from public.point_shop_products p where not(p.product_key=any(keys));
  if exists(select 1 from public.point_shop_products p
    join jsonb_to_recordset(expected) as r(product_key text,kind text,asset_id text,title text,point_price integer,is_active boolean) on p.product_key=r.product_key
    where p.kind is distinct from r.kind or p.asset_id is distinct from r.asset_id
      or p.title is distinct from r.title or p.point_price is distinct from r.point_price or p.is_active is distinct from r.is_active)
  then raise exception 'sensory_release_existing_product_conflict';end if;
  insert into public.point_shop_products(product_key,kind,asset_id,title,point_price,is_active)
    select r.product_key,r.kind,r.asset_id,r.title,r.point_price,r.is_active
    from jsonb_to_recordset(expected) as r(product_key text,kind text,asset_id text,title text,point_price integer,is_active boolean)
    on conflict(product_key) do nothing;
  if (select count(*) from public.point_shop_products p
    join jsonb_to_recordset(expected) as r(product_key text,kind text,asset_id text,title text,point_price integer,is_active boolean) on p.product_key=r.product_key
    where p.kind=r.kind and p.asset_id=r.asset_id and p.title=r.title and p.point_price=r.point_price and p.is_active=r.is_active)<>18
  then raise exception 'sensory_release_registration_incomplete';end if;
  select md5(coalesce(jsonb_agg(to_jsonb(p) order by p.product_key)::text,'[]')) into after_hash
    from public.point_shop_products p where not(p.product_key=any(keys));
  if before_hash is distinct from after_hash then raise exception 'sensory_release_unrelated_catalog_changed';end if;
end;
$sensory_release$;
commit;
