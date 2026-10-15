import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
import {createStoreCurationHandler,validateCuration} from '../../supabase/functions/_shared/store-curation.ts'

const valid={action:'save',placement:'templates',title:'장면을 모아',subtitle:'새 큐레이션',enabled:true,productKeys:['template:shore-days'],expectedVersion:1}
const request=(body,auth='Bearer example')=>new Request('https://example.invalid',{method:'POST',headers:auth?{authorization:auth}:{},body:JSON.stringify(body)})
test('curation denies anonymous, stale, customer and forged metadata before database access',async()=>{
  for(const [auth,user,status]of [[null,null,401],['Bearer stale',null,401],['Bearer customer',{id:'user',app_metadata:{role:'customer'},user_metadata:{role:'admin'}},403]]){
    let touched=false
    const h=createStoreCurationHandler({getUser:async()=>user,createAdminDatabase(){touched=true;throw Error('must not read')}})
    assert.equal((await h(request({action:'overview'},auth))).status,status)
    assert.equal(touched,false)
  }
})
test('validates type, duplicate identities, placement, limits and expected version',()=>{
  assert.equal(validateCuration(valid).p_product_keys[0],'template:shore-days')
  assert.deepEqual(validateCuration({...valid,productKeys:[]}).p_product_keys,[])
  for(const change of [{title:''},{title:'가'.repeat(49)},{subtitle:'가'.repeat(121)},{enabled:1},{productKeys:['template:one','template:one']},
    {productKeys:['frame:one']},{productKeys:[null]},{productKeys:Array.from({length:13},(_,i)=>`template:${i}`)},
    {placement:'home'},{expectedVersion:0},{expectedVersion:'1'}])assert.throws(()=>validateCuration({...valid,...change}))
  assert.throws(()=>validateCuration({...valid,placement:'materials'}))
})
test('save uses only curated fields; stale versions return conflict without leaking database errors',async()=>{
  const calls=[]
  const h=createStoreCurationHandler({getUser:async()=>({id:'admin',app_metadata:{role:'admin'}}),
    createAdminDatabase:()=>({rpc:(name,args)=>({single:async()=>{calls.push({name,args});return{error:{message:'curation_changed PRIVATE_DETAIL'}}}})})})
  const response=await h(request({...valid,pointPrice:0,userId:'victim'}))
  assert.equal(response.status,409)
  assert.deepEqual(await response.json(),{error:'curation_changed'})
  assert.equal(calls[0].name,'save_store_curation')
  assert.equal('pointPrice' in calls[0].args,false)
})

const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
test('SQL: public read-only, service-only writes, active products, atomic order and stale-version protection',async()=>{
  const db=new PGlite()
  try{
    await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
      grant usage on schema public to anon,authenticated,service_role;
      alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
      alter default privileges in schema public grant all on functions to anon,authenticated,service_role;
      create table point_shop_products(product_key text primary key,kind text,is_active boolean,point_price int);
      insert into point_shop_products values('template:a','template',true,0),('template:b','template',true,100),('frame:x','frame',true,20),('template:hidden','template',false,20);
      grant select on point_shop_products to service_role;`)
    await db.exec(readFileSync(new URL('../../supabase/migrations/20261015075743_store_editorial_curations.sql',import.meta.url),'utf8'))
    for(const role of ['anon','authenticated']){
      await db.exec(`set role ${role}`)
      assert.equal((await db.query('select * from store_curations')).rows.length,2)
      await assert.rejects(db.exec("update store_curations set title='hacked'"),/permission denied/)
      await assert.rejects(db.exec("select save_store_curation('templates','x','',true,array['template:a'],1)"),/permission denied/)
      await db.exec('reset role')
    }
    await db.exec('set role service_role')
    const sql=(keys,version=1,enabled=true)=>`select * from save_store_curation('templates','새 컬렉션','소개',${enabled},array[${keys.map(x=>`'${x}'`).join(',')}]::text[],${version})`
    for(const keys of [['frame:x'],['template:hidden'],['template:missing'],['template:a','template:a']])await assert.rejects(db.query(sql(keys)))
    await db.query(sql(['template:b','template:a']))
    assert.deepEqual((await db.query("select product_keys from store_curations where placement='templates'")).rows[0].product_keys,['template:b','template:a'])
    await assert.rejects(db.query(sql(['template:a'])),/curation_changed/)
    await db.query(sql([],2,false))
    await db.exec('reset role;set role anon')
    const row=(await db.query("select * from store_curations where placement='templates'")).rows[0]
    assert.equal(row.enabled,false);assert.deepEqual(row.product_keys,[]);assert.equal(row.version,3)
  }finally{await db.close()}
})
