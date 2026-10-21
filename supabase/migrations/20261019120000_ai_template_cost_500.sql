-- AI 템플릿 생성 포인트 비용을 700 → 500으로 조정.
--
-- 회원가입 보너스 500포인트와 맞추어 신규 회원이
-- 첫 번째(무료 크레딧) + 보너스 포인트로 2번 무료 생성 가능하도록 함.
-- 포인트 패키지(2,200원 → 2,500P)는 5회 추가 생성에 해당.

create or replace function public.ai_album_draft_point_cost()
returns integer
language sql stable
set search_path = ''
as $$
  select 500;
$$;
