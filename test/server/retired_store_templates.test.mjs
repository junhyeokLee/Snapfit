import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { stripTypeScriptTypes } from 'node:module'
import { fileURLToPath } from 'node:url'
import { test } from 'node:test'
import vm from 'node:vm'
import { OrderPaymentError } from '../../supabase/functions/_shared/order-types.ts'
import {
  assertCurrentStoreTemplate, isRetiredStoreTemplate,
  retiredStoreTemplateIds, retiredStoreTemplateTitles, retiredStoreTemplateStems,
} from '../../supabase/functions/_shared/retired-store-templates.ts'

const publishedEntries = JSON.parse(execFileSync('python3', ['-B', '-c',
  "import json,sys;sys.path.insert(0,'tool');from published_catalog_source import published_entries;entries,_=published_entries();print(json.dumps([{'id':e.catalog_id,'slug':e.slug} for e in entries]))",
], { cwd: fileURLToPath(new URL('../../', import.meta.url)), encoding: 'utf8' }))

test('Dart and server retirement policies keep the same catalog identities', () => {
  const dart = readFileSync(new URL('../../lib/core/templates/retired_store_templates.dart', import.meta.url), 'utf8')
  const values = (name, type) => {
    const match = dart.match(new RegExp(`static const ${name} = <${type}>\\{([\\s\\S]*?)\\};`))
    assert.ok(match, `Dart ${name} policy must remain explicit`)
    return type === 'int'
      ? [...match[1].matchAll(/-?\d+/g)].map(value => Number(value[0]))
      : [...match[1].matchAll(/'([^']+)'/g)].map(value => value[1])
  }
  assert.deepEqual(new Set(retiredStoreTemplateIds), new Set(values('ids', 'int')))
  assert.deepEqual(new Set(retiredStoreTemplateTitles), new Set(values('titles', 'String')))
  assert.deepEqual(new Set(retiredStoreTemplateStems), new Set(values('stems', 'String')))
  assert.ok(dart.includes('figma_import_1775063050456'))
})

test('all retired numeric and historical IDs remain blocked after renaming', () => {
  assert.equal(retiredStoreTemplateIds.length, 13)
  for (const id of retiredStoreTemplateIds) {
    for (const value of [id, String(id)]) {
      assert.equal(isRetiredStoreTemplate({ id: value, title: '새로운 이름' }), true)
      assert.throws(() => assertCurrentStoreTemplate({ id: value }), error =>
        error instanceof OrderPaymentError && error.status === 400 && error.message === 'retired_store_template')
    }
  }
})

test('retired titles and versioned document identities cannot obtain new catalog IDs', () => {
  for (const title of retiredStoreTemplateTitles) {
    assert.equal(isRetiredStoreTemplate({ id: 999999, title }), true)
    assert.equal(isRetiredStoreTemplate({ title: `  ${title.toUpperCase().replaceAll(' ', '-')}  ` }), true)
  }
  for (const stem of retiredStoreTemplateStems) {
    for (const identity of [stem, `${stem}_v1`, `${stem}_v12`]) {
      assert.equal(isRetiredStoreTemplate({ title: '새 디자인', templateId: identity }), true)
      for (const document of [{ templateId: identity }, { id: identity }, { metadata: { templateId: identity } }, { metadata: { id: identity } }]) {
        assert.equal(isRetiredStoreTemplate({ templateJson: document }), true)
        assert.equal(isRetiredStoreTemplate({ templateJson: JSON.stringify(document) }), true)
        assert.equal(isRetiredStoreTemplate({ template_json: JSON.stringify(document) }), true)
      }
    }
  }
  assert.equal(isRetiredStoreTemplate({ templateJson: JSON.stringify({ id: 'figma_import_1775063050456' }) }), true)
})

test('new drafts, current negative IDs and shared photos or ordinary layer copy remain valid', () => {
  for (const payload of [
    { title: '새로 만든 사진집' },
    { id: -9501, title: '바다로 향하는 날' },
    { id: -9301, title: '우리의 오늘' },
    { id: 999999, title: '새로운 에디션', templateJson: { templateId: 'new_book_v1' } },
    { title: '필름 다이어리의 다음 이야기' },
    { title: '새로운 사진집', coverImageUrl: 'asset:assets/templates/jeju_travel/images/sources/cover.png' },
    { title: '새로운 사진집', templateJson: JSON.stringify({ pages: [{ layers: [{ text: 'SAVE THE DATE', imageUrl: 'assets/templates/scrapbook/images/sources/photo.jpg' }] }] }) },
    { title: '새로운 사진집', templateJson: '{invalid document' },
  ]) {
    assert.equal(isRetiredStoreTemplate(payload), false)
    assert.doesNotThrow(() => assertCurrentStoreTemplate(payload))
  }
})

test('all 68 current published IDs and source identities remain publishable', () => {
  assert.equal(publishedEntries.length, 68)
  assert.equal(new Set(publishedEntries.map(entry => entry.id)).size, 68)
  for (const entry of publishedEntries) {
    const payload = { id: entry.id, templateId: entry.slug, templateJson: { templateId: entry.slug } }
    assert.equal(isRetiredStoreTemplate(payload), false, entry.slug)
    assert.doesNotThrow(() => assertCurrentStoreTemplate(payload), entry.slug)
  }
})

function endpoint() {
  let serve
  const writes = []
  const source = stripTypeScriptTypes(readFileSync(new URL('../../supabase/functions/admin-ops/index.ts', import.meta.url), 'utf8').replace(/^import .*$/gm, ''))
  vm.runInNewContext(source, {
    Deno: { serve: handler => { serve = handler }, env: { get: key => key === 'SNAPFIT_ADMIN_KEY' ? 'fixture-admin' : undefined } },
    adminClient: () => ({ from(table) {
      assert.equal(table, 'templates')
      return { upsert(payload) {
        writes.push(payload)
        return { select: () => ({ single: async () => ({ data: { id: 999999, ...payload }, error: null }) }) }
      } }
    } }),
    assertCurrentStoreTemplate, OrderPaymentError, Response,
    corsHeaders: {}, console: { error() {} },
    jsonResponse: (body, status = 200) => Response.json(body, { status }),
  })
  return {
    writes,
    request: payload => serve(new Request('https://admin-fixture.invalid', {
      method: 'POST', body: JSON.stringify({ action: 'upsertTemplate', adminKey: 'fixture-admin', payload }),
    })),
  }
}

test('authenticated admin endpoint rejects old registrations before any database write', async () => {
  const run = endpoint()
  for (const payload of [
    ...retiredStoreTemplateIds.map(id => ({ id, title: '임의의 이름' })),
    ...retiredStoreTemplateTitles.map(title => ({ title })),
    ...retiredStoreTemplateStems.map(stem => ({ title: '임의의 이름', templateId: `${stem}_v1` })),
    ...retiredStoreTemplateStems.map(stem => ({ title: '임의의 이름', templateJson: JSON.stringify({ templateId: `${stem}_v1` }) })),
  ]) {
    const response = await run.request(payload)
    assert.equal(response.status, 400)
    assert.deepEqual(await response.json(), { error: 'retired_store_template' })
  }
  assert.equal(run.writes.length, 0)
})

test('authenticated admin endpoint preserves current IDs and allows ordinary new templates', async () => {
  const run = endpoint()
  const current = await run.request({ id: -9501, title: '새로운 현행 디자인', templateJson: '{"templateId":"shore_days_v1"}' })
  assert.equal(current.status, 200)
  assert.equal((await current.json()).id, -9501)
  const created = await run.request({ title: '직접 만든 새 디자인' })
  assert.equal(created.status, 200)
  assert.equal(run.writes.length, 2)
  assert.equal(run.writes[0].id, -9501)
  assert.equal('id' in run.writes[1], false)
})
