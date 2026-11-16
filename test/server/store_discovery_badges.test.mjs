import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {test} from 'node:test'
import {PGlite} from '@electric-sql/pglite'

const sql=readFileSync(new URL('../../supabase/migrations/20261103024536_store_discovery_badge_rules.sql',import.meta.url),'utf8')
async function fixture(){
  const db=new PGlite()
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
    grant usage on schema public to anon,authenticated,service_role;
    create table point_shop_products(product_key text primary key,kind text,is_active boolean,point_price integer);
    create table point_shop_ownership(user_id text,product_key text references point_shop_products,created_at timestamptz,primary key(user_id,product_key));
    insert into point_shop_products values('template:story-coffee-notebook','template',true,0),('template:story-night-city-archive','template',true,1800),('template:old','template',true,100);
    create table customer_sentinel(balance integer,album jsonb);insert into customer_sentinel values(7100,'{"photo":"unchanged","font":"BookMyungjo"}');`)
  await db.exec(sql)
  return db
}
test('public metadata is read-only and anonymous callers cannot read purchases or publication rows',async t=>{
  const db=await fixture();t.after(()=>db.close())
  const sentinel=(await db.query('select * from customer_sentinel')).rows
  for(const role of ['anon','authenticated']){
    await db.exec(`set role ${role}`)
    const rows=(await db.query('select * from get_store_product_discovery()')).rows
    assert.equal(rows.length,3)
    assert.deepEqual(Object.keys(rows[0]).sort(),['best_rank','first_published_at','product_key'])
    assert.ok(rows.every(r=>r.best_rank===null))
    assert.ok(rows.find(r=>r.product_key==='template:story-coffee-notebook').first_published_at)
    assert.equal(rows.find(r=>r.product_key==='template:old').first_published_at,null)
    await assert.rejects(db.query('select * from point_shop_ownership'),/permission denied/)
    await assert.rejects(db.query('select * from store_private.product_publications'),/permission denied/)
    await assert.rejects(db.exec("update store_private.product_publications set first_published_at=now()"),/permission denied/)
    await db.exec('reset role')
  }
  assert.deepEqual((await db.query('select * from customer_sentinel')).rows,sentinel)
})
test('BEST requires ten distinct recent acquisitions, ranks at most five per kind and ignores old, future, inactive and unpriced products',async t=>{
  const db=await fixture();t.after(()=>db.close())
  for(const kind of ['template','frame'])for(let i=0;i<7;i++){
    const key=`${kind}:rank-${i}`
    await db.query('insert into point_shop_products values($1,$2,true,100)',[key,kind])
    await db.query("insert into point_shop_ownership select 'user-'||n,$1,now()-interval '1 day' from generate_series(1,$2) n",[key,20-i])
  }
  for(const [key,active,price,age,count]of [['template:short',true,100,'1 day',9],['template:stale',true,100,'31 days',50],['template:future',true,100,'-1 day',50],['template:hidden',false,100,'1 day',100],['template:unpriced',true,null,'1 day',100]]){
    await db.query('insert into point_shop_products values($1,\'template\',$2,$3)',[key,active,price])
    await db.query("insert into point_shop_ownership select 'user-'||n,$1,now()-$2::interval from generate_series(1,$3) n",[key,age,count])
  }
  const rows=(await db.query('select * from get_store_product_discovery()')).rows
  assert.equal(rows.filter(r=>r.best_rank!==null).length,10)
  for(const kind of ['template','frame']){
    const top=rows.filter(r=>r.product_key.startsWith(kind+':')&&r.best_rank!==null).sort((a,b)=>a.best_rank-b.best_rank)
    assert.deepEqual(top.map(r=>r.product_key),Array.from({length:5},(_,i)=>`${kind}:rank-${i}`))
  }
  assert.equal(rows.find(r=>r.product_key==='template:short').best_rank,null)
  assert.equal(rows.find(r=>r.product_key==='template:stale').best_rank,null)
  assert.equal(rows.find(r=>r.product_key==='template:future').best_rank,null)
  assert.ok(!rows.some(r=>['template:hidden','template:unpriced'].includes(r.product_key)))
})
test('publication registry cannot be reset by routine service updates',async t=>{
  const db=await fixture();t.after(()=>db.close())
  await db.exec('set role service_role')
  await assert.rejects(db.exec('update store_private.product_publications set first_published_at=now()'),/permission denied/)
  await assert.rejects(db.exec('delete from store_private.product_publications'),/permission denied/)
})
