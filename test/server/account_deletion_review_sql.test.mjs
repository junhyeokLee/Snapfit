import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const migration=readFileSync(new URL('../../supabase/migrations/20261018184830_account_deletion_review_requests.sql',import.meta.url),'utf8')
test('active deletion inquiries are unique per owner without altering accounts or other inquiry types',async()=>{
 const db=new PGlite();try{
  await db.exec('create table public.support_inquiries(id bigint generated always as identity,user_id uuid,category text,status text)')
  await db.exec(migration)
  const owner='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222'
  const insert=(actor=owner,category='ACCOUNT_DELETION',status='OPEN')=>db.query('insert into public.support_inquiries(user_id,category,status) values($1,$2,$3)',[actor,category,status])
  await insert();await assert.rejects(insert(),/duplicate key/);await assert.rejects(insert(owner,'ACCOUNT_DELETION','IN_PROGRESS'),/duplicate key/)
  await insert(other);await insert(owner,'GENERAL');await insert(owner,'GENERAL');
  await db.exec("update public.support_inquiries set status='RESOLVED' where category='ACCOUNT_DELETION'")
  await insert();assert.equal((await db.query('select count(*)::int n from public.support_inquiries')).rows[0].n,5)
 }finally{await db.close()}
})
