// Requires @electric-sql/pglite (tested with 0.3.14). PGLITE_MODULE may point to
// an existing installation. Every test creates a fresh, in-memory PostgreSQL DB.
import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";
const { PGlite } = await import(
  process.env.PGLITE_MODULE ?? "@electric-sql/pglite"
);
const migration = (name) =>
  readFileSync(new URL(`../migrations/${name}`, import.meta.url), "utf8");
const a = "11111111-1111-4111-8111-111111111111";
const b = "22222222-2222-4222-8222-222222222222";
const productId = "snapfit_points_2500";
const purchase = (transactionId = "google-token-1", overrides = {}) => ({
  platform: "GOOGLE_PLAY",
  productId,
  transactionId,
  purchaseToken: transactionId,
  originalTransactionId: "google-order-1",
  storeAccountId: a,
  purchasedAt: "2026-09-08T00:00:00Z",
  rawResponse: { purchaseStateContext: { purchaseState: "PURCHASED" } },
  ...overrides,
});

async function fixture() {
  const db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create schema extensions;
    create function extensions.gen_random_uuid() returns uuid language sql as $$ select pg_catalog.gen_random_uuid() $$;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
    create function public.is_admin() returns boolean language sql stable as $$ select false $$;
    create function public.set_updated_at() returns trigger language plpgsql as $$
    begin new.updated_at = now(); return new; end; $$;
    create table public.billing_plans(
      plan_code text primary key, title text, amount integer, currency text,
      provider text, is_active boolean not null default true
    );
    insert into public.billing_plans(plan_code) values ('FREE'), ('SNAPFIT_PRO_MONTHLY');
    create table public.subscriptions(user_id uuid primary key references auth.users,
      plan_code text references public.billing_plans, status text);
    insert into auth.users values ('${a}'), ('${b}');
    insert into subscriptions values ('${a}', 'SNAPFIT_PRO_MONTHLY', 'ACTIVE');
  `);
  // Actual earlier purchase/point migrations, including their old grant RPC.
  for (
    const file of [
      "20260820161000_store_iap_entitlements.sql",
      "20260905113000_ai_album_points.sql",
      "20260905193000_ai_album_hybrid_pricing.sql",
      "20260905201000_fix_grant_point_purchase_ambiguity.sql",
      "20260905203000_ai_album_profit_pricing.sql",
      "20260905212500_fix_admin_point_operations_lint.sql",
    ]
  ) await db.exec(migration(file));
  await db.exec(migration("20260908094449_point_only_iap_atomic_grants.sql"));
  await db.exec(
    migration("20260908095746_point_purchase_refund_reconciliation.sql"),
  );
  return db;
}
const grant = async (db, user = a, data = purchase()) =>
  (await db.query(
    "select * from public.grant_verified_point_purchase($1::uuid, $2::jsonb)",
    [user, JSON.stringify(data)],
  )).rows[0];
const balance = async (db, user = a) =>
  (await db.query("select balance from point_wallets where user_id=$1", [user]))
    .rows[0]?.balance ?? 0;
const counts = async (db) =>
  (await db.query(
    "select (select count(*)::int from store_purchases) purchases, (select count(*)::int from point_ledger) ledger",
  )).rows[0];
const revoke = async (db, platform = "GOOGLE_PLAY", id = "google-token-1") =>
  (await db.query(
    "select * from revoke_verified_point_purchase($1,$2,$3::jsonb)",
    [
      platform,
      id,
      JSON.stringify({ purchaseStateContext: { purchaseState: "CANCELLED" } }),
    ],
  )).rows[0];

test("RPC grants configured points exactly once and retains subscription history inactive for sale", async () => {
  const db = await fixture();
  try {
    const first = await grant(db);
    assert.deepEqual(first, {
      product_id: productId,
      granted_points: 2500,
      remaining_balance: 2500,
      already_granted: false,
    });
    const retry = await grant(
      db,
      a,
      purchase("google-token-1", {
        originalTransactionId: "client-changed-id",
        points: 999999,
      }),
    );
    assert.deepEqual(retry, { ...first, already_granted: true });
    assert.deepEqual(await counts(db), { purchases: 1, ledger: 1 });
    assert.equal(
      (await db.query(
        "select is_active from billing_plans where plan_code='SNAPFIT_PRO_MONTHLY'",
      )).rows[0].is_active,
      false,
    );
    assert.equal(
      (await db.query("select count(*)::int n from subscriptions")).rows[0].n,
      1,
    );
  } finally {
    await db.close();
  }
});

test("authenticated and anon cannot execute either grant RPC; only service_role can use atomic grant", async () => {
  const db = await fixture();
  try {
    const privileges = (await db.query(`select r,
      has_function_privilege(r, 'public.grant_verified_point_purchase(uuid,jsonb)', 'EXECUTE') atomic,
      has_function_privilege(r, 'public.grant_point_purchase(uuid,text,text,text)', 'EXECUTE') retired
      from unnest(array['anon','authenticated','service_role']) r`)).rows;
    assert.deepEqual(privileges, [
      { r: "anon", atomic: false, retired: false },
      { r: "authenticated", atomic: false, retired: false },
      { r: "service_role", atomic: true, retired: false },
    ]);
    for (const role of ["anon", "authenticated"]) {
      await db.exec(`set role ${role}`);
      await assert.rejects(() => grant(db), /permission denied/);
      await db.exec("reset role");
    }
    await db.exec("set role service_role");
    assert.equal((await grant(db)).granted_points, 2500);
    await db.exec("reset role");
  } finally {
    await db.close();
  }
});

test("missing or foreign store account binding cannot create a fresh credit", async () => {
  const db = await fixture();
  try {
    await assert.rejects(
      () => grant(db, a, purchase("missing-account", { storeAccountId: null })),
      /purchase_account_required/,
    );
    await assert.rejects(
      () => grant(db, a, purchase("foreign-account", { storeAccountId: b })),
      /purchase_account_mismatch/,
    );
    assert.deepEqual(await counts(db), { purchases: 0, ledger: 0 });
    assert.equal(await balance(db), 0);
  } finally {
    await db.close();
  }
});

test("canonical identity cannot move between accounts or products", async () => {
  const db = await fixture();
  try {
    await grant(db);
    await assert.rejects(
      () => grant(db, b, purchase("google-token-1", { storeAccountId: b })),
      /purchase_owner_mismatch/,
    );
    await assert.rejects(
      () =>
        grant(
          db,
          a,
          purchase("google-token-1", { productId: "snapfit_points_18000" }),
        ),
      /purchase_identity_conflict/,
    );
    await assert.rejects(
      () =>
        grant(db, a, purchase("fake-id", { purchaseToken: "google-token-1" })),
      /purchase_identity_conflict/,
    );
    assert.equal(await balance(db), 2500);
    assert.equal(await balance(db, b), 0);
    assert.equal(
      (await db.query("select user_id from store_purchases")).rows[0].user_id,
      a,
    );
  } finally {
    await db.close();
  }
});

test("concurrent retries of one token and independent tokens cannot lose or duplicate credits", async () => {
  const db = await fixture();
  try {
    const retries = await Promise.all(
      Array.from({ length: 8 }, () => grant(db)),
    );
    assert.equal(retries.filter((row) => !row.already_granted).length, 1);
    await Promise.all(
      Array.from(
        { length: 8 },
        (_, i) => grant(db, a, purchase(`separate-${i}`)),
      ),
    );
    assert.equal(await balance(db), 22500);
    assert.deepEqual(await counts(db), { purchases: 9, ledger: 9 });
    // PGlite serializes connections; advisory locking is still in the real SQL.
    // This probes repeated async delivery, not a multi-connection stress test.
  } finally {
    await db.close();
  }
});

test("failure recording the receipt rolls back both ledger and wallet credit", async () => {
  const db = await fixture();
  try {
    await db.exec(
      `create function fail_receipt_insert() returns trigger language plpgsql as $$
      begin raise exception 'injected receipt storage failure'; end; $$;
      create trigger fail_receipt before insert on store_purchases for each row execute function fail_receipt_insert();`,
    );
    await assert.rejects(() => grant(db), /injected receipt storage failure/);
    assert.deepEqual(await counts(db), { purchases: 0, ledger: 0 });
    assert.equal(await balance(db), 0);
  } finally {
    await db.close();
  }
});

async function legacy(
  db,
  {
    owner = a,
    status = "VERIFIED",
    raw = "{}",
    ledger = true,
    id = "legacy-order",
    token = "legacy-token",
  } = {},
) {
  await db.query(
    `insert into store_purchases(user_id,platform,product_id,transaction_id,purchase_token,status,plan_code,raw_response)
    values($1,'GOOGLE_PLAY',$2,$3,$4,$5,'FREE',$6::jsonb)`,
    [owner, productId, id, token, status, raw],
  );
  if (ledger) {
    await db.query(
      `insert into point_wallets(user_id,balance) values($1,2500) on conflict(user_id) do nothing`,
      [owner],
    );
    await db.query(
      `insert into point_ledger(user_id,amount_delta,reason,idempotency_key,metadata)
      values($1,2500,'POINT_PURCHASE',$2,$3::jsonb)`,
      [
        owner,
        `point_purchase:GOOGLE_PLAY:${id}`,
        JSON.stringify({ product_id: productId }),
      ],
    );
  }
}

test("verified credited legacy purchase can retry without account token and keeps its ledger/history", async () => {
  const db = await fixture();
  try {
    await legacy(db);
    const result = await grant(
      db,
      a,
      purchase("legacy-token", { storeAccountId: null }),
    );
    assert.equal(result.already_granted, true);
    assert.equal(await balance(db), 2500);
    assert.deepEqual(await counts(db), { purchases: 1, ledger: 1 });
    const row = (await db.query(
      "select transaction_id,canonical_transaction_id,point_ledger_id from store_purchases",
    )).rows[0];
    assert.equal(row.transaction_id, "legacy-order");
    assert.equal(row.canonical_transaction_id, "legacy-token");
    assert.ok(row.point_ledger_id);
  } finally {
    await db.close();
  }
});

test("pending, uncredited, mock or foreign legacy history cannot authorize a missing account token", async () => {
  for (
    const options of [{ status: "PENDING" }, { ledger: false }, {
      raw: '{"mock":true}',
    }, { owner: b }]
  ) {
    const db = await fixture();
    try {
      await legacy(db, options);
      const before = await counts(db);
      await assert.rejects(
        () => grant(db, a, purchase("legacy-token", { storeAccountId: null })),
        /purchase_account_required|purchase_owner_mismatch/,
      );
      assert.deepEqual(await counts(db), before);
    } finally {
      await db.close();
    }
  }
});

test("ambiguous historical token replays fail closed", async () => {
  const db = await fixture();
  try {
    await legacy(db);
    await legacy(db, { id: "another-legacy-order", ledger: false });
    await assert.rejects(
      () => grant(db, a, purchase("legacy-token")),
      /purchase_legacy_conflict/,
    );
    assert.equal(await balance(db), 2500);
  } finally {
    await db.close();
  }
});

test("historical inactive point SKUs remain fulfillable; retries preserve credited amount and subscriptions fail", async () => {
  const db = await fixture();
  try {
    await grant(db);
    await db.query(
      "update point_products set is_active=false,points=9000 where product_id=$1",
      [productId],
    );
    assert.equal((await grant(db)).granted_points, 2500);
    assert.equal(
      (await grant(db, a, purchase("new-inactive"))).granted_points,
      9000,
    );
    await assert.rejects(
      () =>
        grant(
          db,
          a,
          purchase("subscription", { productId: "snapfit_pro_monthly" }),
        ),
      /unknown_point_product/,
    );
    assert.equal(await balance(db), 11500);
  } finally {
    await db.close();
  }
});

test("a historically revoked receipt cannot be resurrected", async () => {
  const db = await fixture();
  try {
    await grant(db);
    await db.exec("update store_purchases set status='REFUNDED'");
    await assert.rejects(() => grant(db), /purchase_revoked/);
    assert.equal(await balance(db), 2500);
  } finally {
    await db.close();
  }
});

test("Apple canonical transaction uses the same once-only grant with its appAccountToken", async () => {
  const db = await fixture();
  try {
    const data = purchase("2000000123456789", {
      platform: "APP_STORE",
      purchaseToken: null,
    });
    assert.equal((await grant(db, a, data)).already_granted, false);
    assert.equal((await grant(db, a, data)).already_granted, true);
    await assert.rejects(
      () => grant(db, b, { ...data, storeAccountId: b }),
      /purchase_owner_mismatch/,
    );
    assert.deepEqual(await counts(db), { purchases: 1, ledger: 1 });
  } finally {
    await db.close();
  }
});

test("refund reverses the original credit once, preserves spent debt and future grants offset it", async () => {
  const db = await fixture();
  try {
    await grant(db);
    await db.exec(`update point_wallets set balance=500;
      insert into point_ledger(user_id,amount_delta,reason,idempotency_key) values('${a}',-2000,'AI_ALBUM_DRAFT_CHARGE','spent-before-refund');
      update point_products set points=9000 where product_id='${productId}';`);
    const first = await revoke(db);
    assert.deepEqual(first, {
      revoked_points: 2500,
      remaining_balance: -2000,
      already_revoked: false,
    });
    assert.deepEqual(await revoke(db), { ...first, already_revoked: true });
    assert.equal(
      (await db.query(
        "select count(*)::int n from point_ledger where reason='POINT_PURCHASE_REFUND'",
      )).rows[0].n,
      1,
    );
    assert.equal(
      (await db.query("select status from store_purchases")).rows[0].status,
      "REFUNDED",
    );
    await assert.rejects(() => grant(db), /purchase_revoked/);
    await db.query(
      "update point_products set points=2500 where product_id=$1",
      [productId],
    );
    assert.equal(
      (await grant(db, a, purchase("next-real-purchase"))).remaining_balance,
      500,
    );
  } finally {
    await db.close();
  }
});

test("refund debt blocks paid AI usage and admin adjustments preserve the exact debt", async () => {
  const db = await fixture();
  try {
    await grant(db);
    await db.exec(`update point_wallets set balance=0;
      create or replace function auth.uid() returns uuid language sql stable as $$ select '${a}'::uuid $$;
      insert into ai_album_free_draft_claims(user_id,draft_id) values('${a}','prior-free');`);
    await revoke(db);
    await assert.rejects(
      () =>
        db.query("select * from record_ai_album_draft_success($1,700)", [
          "new-paid-draft",
        ]),
      /insufficient points/,
    );
    await db.exec(
      "create or replace function public.is_admin() returns boolean language sql stable as $$ select true $$",
    );
    await db.query("select * from admin_adjust_user_points($1,100,$2,$3)", [
      a,
      "explicit CS adjustment",
      "cs-debt-adjustment",
    ]);
    assert.equal(await balance(db), -2400);
  } finally {
    await db.close();
  }
});

test("refund failure rolls back debt, refund ledger and status together", async () => {
  const db = await fixture();
  try {
    await grant(db);
    await db.exec(
      `create function fail_refund_update() returns trigger language plpgsql as $$
      begin if new.status='REFUNDED' then raise exception 'injected refund storage failure'; end if; return new; end; $$;
      create trigger fail_refund before update on store_purchases for each row execute function fail_refund_update();`,
    );
    await assert.rejects(() => revoke(db), /injected refund storage failure/);
    assert.equal(await balance(db), 2500);
    assert.deepEqual(await counts(db), { purchases: 1, ledger: 1 });
    assert.equal(
      (await db.query("select status from store_purchases")).rows[0].status,
      "VERIFIED",
    );
  } finally {
    await db.close();
  }
});

test("reconciliation RPCs are service-only and leases prevent repeat work or stale completion", async () => {
  const db = await fixture();
  try {
    for (
      const signature of [
        "revoke_verified_point_purchase(text,text,jsonb)",
        "claim_point_purchase_reconciliation(integer)",
        "finish_point_purchase_reconciliation(bigint,uuid,text)",
      ]
    ) {
      for (const role of ["anon", "authenticated", "service_role"]) {
        assert.equal(
          (await db.query(
            "select has_function_privilege($1,$2,'EXECUTE') allowed",
            [role, signature],
          )).rows[0].allowed,
          role === "service_role",
        );
      }
    }
    await grant(db);
    const first =
      (await db.query("select * from claim_point_purchase_reconciliation(20)"))
        .rows;
    assert.equal(first.length, 1);
    assert.equal(
      (await db.query("select * from claim_point_purchase_reconciliation(20)"))
        .rows.length,
      0,
    );
    assert.equal(
      (await db.query(
        "select finish_point_purchase_reconciliation($1,$2,$3) updated",
        [first[0].purchase_id, b, null],
      )).rows[0].updated,
      false,
    );
    assert.equal(
      (await db.query(
        "select finish_point_purchase_reconciliation($1,$2,$3) updated",
        [first[0].purchase_id, first[0].lease_id, "provider_unavailable"],
      )).rows[0].updated,
      true,
    );
    const row = (await db.query(
      "select reconcile_error,reconcile_lease_id,reconcile_after>now() delayed from store_purchases",
    )).rows[0];
    assert.deepEqual(row, {
      reconcile_error: "provider_unavailable",
      reconcile_lease_id: null,
      delayed: true,
    });
    await db.exec(
      "update store_purchases set reconcile_after=now()-interval '1 minute'",
    );
    const retry =
      (await db.query("select * from claim_point_purchase_reconciliation(20)"))
        .rows[0];
    assert.notEqual(retry.lease_id, first[0].lease_id);
    await revoke(db);
    await db.query("select finish_point_purchase_reconciliation($1,$2,null)", [
      retry.purchase_id,
      retry.lease_id,
    ]);
    assert.equal(
      (await db.query("select * from claim_point_purchase_reconciliation(20)"))
        .rows.length,
      0,
    );
  } finally {
    await db.close();
  }
});

test("legacy point credits are linked for reconciliation without a second grant or rewriting history", async () => {
  const db = await fixture();
  try {
    await legacy(db);
    await db.exec(
      migration("20260908095746_point_purchase_refund_reconciliation.sql"),
    );
    const claims =
      (await db.query("select * from claim_point_purchase_reconciliation(20)"))
        .rows;
    assert.equal(claims.length, 1);
    assert.equal(claims[0].transaction_id, "legacy-token");
    assert.equal(
      (await revoke(db, "GOOGLE_PLAY", "legacy-token")).revoked_points,
      2500,
    );
    assert.equal(await balance(db), 0);
    assert.equal(
      (await db.query("select transaction_id from store_purchases")).rows[0]
        .transaction_id,
      "legacy-order",
    );
  } finally {
    await db.close();
  }
});
