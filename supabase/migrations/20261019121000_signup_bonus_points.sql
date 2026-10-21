-- 회원가입 보너스 포인트 500P 자동 지급.
--
-- auth.users 에 신규 행이 삽입되면 트리거가 실행되어
-- point_wallets 에 500포인트를 초기 잔액으로 지급한다.
-- 이미 지갑이 있는 경우(소셜 로그인 재가입 등)는 중복 지급하지 않는다.
-- idempotency_key 'signup_bonus:<user_id>' 로 ledger 중복도 차단한다.

-- 1. reason 열의 CHECK constraint 에 SIGNUP_BONUS 추가
alter table public.point_ledger
  drop constraint if exists point_ledger_reason_check;

alter table public.point_ledger
  add constraint point_ledger_reason_check
  check (reason in (
    'AI_ALBUM_DRAFT_FREE',
    'AI_ALBUM_DRAFT_CHARGE',
    'ADMIN_ADJUSTMENT',
    'POINT_PURCHASE',
    'DIGITAL_ITEM_PURCHASE',
    'SIGNUP_BONUS'
  ));

-- 2. 신규 가입 포인트 지급 함수
create or replace function public.grant_signup_bonus()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- 지갑이 없으면 500포인트로 생성, 이미 있으면 건너뜀
  insert into public.point_wallets(user_id, balance)
  values (new.id, 500)
  on conflict (user_id) do nothing;

  -- ledger 에 기록 (idempotency_key 충돌 시 중복 지급 없음)
  insert into public.point_ledger(
    user_id,
    amount_delta,
    reason,
    idempotency_key,
    metadata
  ) values (
    new.id,
    500,
    'SIGNUP_BONUS',
    'signup_bonus:' || new.id::text,
    '{}'::jsonb
  )
  on conflict (idempotency_key) do nothing;

  return new;
end;
$$;

-- 3. auth.users INSERT 트리거 연결
drop trigger if exists on_auth_user_created_grant_points on auth.users;
create trigger on_auth_user_created_grant_points
  after insert on auth.users
  for each row execute function public.grant_signup_bonus();
