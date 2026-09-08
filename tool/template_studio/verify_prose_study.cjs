const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/prose-study/browser');
fs.mkdirSync(out, {recursive: true});
const checks = [];

function colors(bytes) {
  const png = PNG.sync.read(bytes), values = new Set();
  for (let i = 0; i < png.data.length; i += 16) {
    values.add(`${png.data[i] >> 3},${png.data[i + 1] >> 3},${png.data[i + 2] >> 3}`);
  }
  return values.size;
}
async function enable(page) {
  const ready = page.getByRole('button', {name: '문구 조판', exact: true});
  await expect.poll(async () => await ready.isVisible() || await page.locator('flt-semantics-placeholder').count() > 0, {timeout:30000}).toBe(true);
  // Chrome may enable semantics itself on reload and remove the placeholder.
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await expect(ready).toBeVisible({timeout: 30000});
}
async function choose(page, name, option) {
  await page.getByRole('button', {name, exact: true}).click();
  await page.getByRole('menuitem', {name: option, exact: true}).click();
  await expect(page.getByRole('menu')).toHaveCount(0);
}
async function snap(page, name) {
  await page.mouse.move(1, 1);
  await page.waitForTimeout(1000);
  const bytes = await page.screenshot({path: path.join(out, name)});
  assert(colors(bytes) > 100, `${name}: blank render`);
}
async function reach(page, control) {
  const v = page.viewportSize();
  for (let i = 0; i < 30; i++) {
    const b = await control.boundingBox().catch(() => null);
    if (b && b.y >= 56 && b.y + b.height <= v.height) return;
    await page.mouse.move(v.width - 12, v.height * .7);
    await page.mouse.wheel(0, b ? Math.max(-180, Math.min(180, b.y - v.height * .4)) : 180);
    await page.waitForTimeout(150);
  }
  throw new Error('Gallery control unreachable');
}
function star(page, name, saved = false) {
  return page.getByLabel(`${name} 즐겨찾기 ${saved ? '해제' : '추가'}`, {exact: true});
}
async function fill(page, label, value) {
  const field = page.getByRole('textbox', {name: new RegExp(`^${label}`)});
  const v = page.viewportSize();
  for (let i = 0; i < 30; i++) {
    const b = await field.count() ? await field.boundingBox() : null;
    if (b && b.y >= Math.max(65, v.height * .1 + 56) && b.y + b.height <= v.height - 25) break;
    await page.mouse.move(v.width / 2, v.height * .7);
    await page.mouse.wheel(0, b ? Math.max(-160, Math.min(160, b.y - v.height * .4)) : 160);
    await page.waitForTimeout(150);
  }
  await field.click();
  const input = page.locator('input:focus, textarea:focus');
  await expect(input).toBeFocused();
  await page.waitForTimeout(150);
  await input.fill(value);
  await expect(input).toHaveValue(value);
  await page.waitForTimeout(150);
}
async function savedKeys(page) {
  return page.evaluate(() => {
    const raw = localStorage.getItem('flutter.catalog_favorites_v1');
    if (!raw) return [];
    const decoded = JSON.parse(raw);
    return (typeof decoded === 'string' ? JSON.parse(decoded) : decoded).keys;
  });
}

(async () => {
  const art = PNG.sync.read(fs.readFileSync('assets/templates/prose_study/botanical_cartouche.png'));
  let transparent = 0, dense = 0;
  for (let i = 3; i < art.data.length; i += 4) {
    if (art.data[i] === 0) transparent++;
    if (art.data[i] >= 240) dense++;
  }
  assert(art.width >= 1024 && art.height >= 1024);
  assert(transparent > art.width * art.height * .2);
  assert(dense > art.width * art.height * .1);
  checks.push({asset: 'botanical_cartouche', width: art.width, height: art.height, transparent, dense});
  function luminance(r, g, b) {
    const linear = c => c / 255 <= .04045 ? c / 255 / 12.92 : ((c / 255 + .055) / 1.055) ** 2.4;
    return .2126 * linear(r) + .7152 * linear(g) + .0722 * linear(b);
  }
  const ink = PNG.sync.read(fs.readFileSync('assets/templates/prose_study/woodcut_ink.png'));
  let minContrast = Infinity;
  for (let i = 0; i < ink.data.length; i += 4) {
    assert(ink.data[i + 3] >= 250, 'Lettering fill must remain opaque');
    minContrast = Math.min(minContrast, (luminance(250, 250, 246) + .05) /
      (luminance(ink.data[i], ink.data[i + 1], ink.data[i + 2]) + .05));
  }
  assert(minContrast >= 4.5, 'Ink texture must not erase letter strokes on paper');
  checks.push({asset: 'woodcut_ink', width: ink.width, height: ink.height, minContrast});
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    for (const viewport of [{width: 390, height: 844}, {width: 844, height: 390}, {width: 1440, height: 900}]) {
      const context = await browser.newContext({viewport});
      const page = await context.newPage();
      page.setDefaultTimeout(15000);
      const errors = [], failures = [], api = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => {if (r.status() >= 400) failures.push(r.url());});
      page.on('request', r => {if (/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url());});
      await page.goto(`${root}/?collection=our-prose#/our-prose`);
      await enable(page);
      await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('무료 · 표지 + 내지 24쪽');
      await expect(page.getByRole('button', {name: /^표지 미리보기.*함께여서.*좋은 날/})).toBeVisible();
      for (const ratio of ['세로형', '정사각형', '가로형']) {
        await choose(page, '앨범 규격', ratio);
        const cover = page.getByRole('button', {name: /^표지 미리보기/});
        await expect(cover).toBeVisible();
        await expect.poll(async () => colors(await cover.screenshot())).toBeGreaterThan(100);
        const b = await cover.boundingBox();
        assert(b.x >= 0 && b.y >= 0 && b.x + b.width <= viewport.width + 1 && b.y + b.height <= viewport.height + 1);
        await snap(page, `${viewport.width}-${ratio}-cover.png`);
      }
      await choose(page, '앨범 규격', '정사각형');
      for (const [i, name] of ['웃음이 먼저 남은 날', '나란히 앉은 오후', '당신에게 쓰는 편지'].entries()) {
        await choose(page, '목차', `${i * 2 + 1}–${i * 2 + 2} / ${name}`);
        await expect(page.getByRole('button', {name: new RegExp(`^${i * 2 + 1}쪽 미리보기`)})).toBeVisible();
        await snap(page, `${viewport.width}-spread-${i + 1}.png`);
        if (i > 0) {
          if (viewport.width < 600) await page.getByRole('button', {name: '다음 페이지', exact: true}).click();
          await expect(page.getByRole('button', {name: new RegExp(`^${i * 2 + 2}쪽 미리보기`)})).toBeVisible();
          await snap(page, `${viewport.width}-page-${i * 2 + 2}.png`);
        }
      }
      await page.getByRole('button', {name: '전체 펼침 보기', exact: true}).click();
      await snap(page, `${viewport.width}-overview.png`);
      await page.getByRole('button', {name: '책으로 보기', exact: true}).click();
      await page.getByRole('button', {name: '문구 편집', exact: true}).click();
      await fill(page, '표제 윗줄', '함께하는');
      await fill(page, '강조 단어', '계절');
      await snap(page, `${viewport.width}-copy-sheet.png`);
      await fill(page, '4쪽 짧은 기록', '함께 걸었던 오후.');
      await fill(page, '24쪽 마무리', '또 만나, 우리.');
      await snap(page, `${viewport.width}-closing-edit.png`);
      await page.getByRole('button', {name: '문구 적용', exact: true}).click();
      await expect(page.getByRole('button', {name: '문구 적용', exact: true})).toHaveCount(0);
      await choose(page, '목차', '3–4 / 나란히 앉은 오후');
      if (viewport.width < 600) await page.getByRole('button', {name: '다음 페이지', exact: true}).click();
      await expect(page.getByRole('button', {name: /^4쪽 미리보기.*함께 걸었던 오후/})).toBeVisible();
      await choose(page, '목차', '23–24 / 다음에도, 이렇게');
      if (viewport.width < 600) await page.getByRole('button', {name: '다음 페이지', exact: true}).click();
      await expect(page.getByRole('button', {name: /^24쪽 미리보기.*또 만나.*우리/})).toBeVisible();
      await page.getByRole('button', {name: '문구 조판', exact: true}).click();
      await snap(page, `${viewport.width}-gallery.png`);
      await reach(page, star(page, '패턴으로 쓴 표제'));
      await star(page, '패턴으로 쓴 표제').click();
      await reach(page, star(page, '장면을 여는 문장'));
      await star(page, '장면을 여는 문장').click();
      await expect.poll(() => savedKeys(page)).toEqual(['textStyle:prose-study:cascade', 'textStyle:prose-study:cartouche']);
      await page.getByRole('checkbox', {name: /즐겨찾기/}).click();
      const selected = page.getByLabel(/즐겨찾기 해제$/);
      await expect(selected).toHaveCount(2);
      assert.deepEqual(await selected.evaluateAll(nodes => nodes.map(n => n.getAttribute('aria-label'))), ['장면을 여는 문장 즐겨찾기 해제', '패턴으로 쓴 표제 즐겨찾기 해제']);
      await snap(page, `${viewport.width}-favorites.png`);
      const first = page.getByRole('button', {name: '장면을 여는 문장 페이지 보기', exact: true});
      // The square gallery tile can exceed a short landscape viewport. Tap its visible center area.
      const firstBox = await first.boundingBox();
      await first.click({position: {x: firstBox.width / 2, y: Math.min(100, firstBox.height / 2)}});
      await expect(page.getByRole('button', {name: /^1쪽 미리보기/})).toBeVisible();
      await page.getByRole('button', {name: '문구 편집', exact: true}).click();
      await fill(page, '강조 단어', '');
      await page.getByRole('button', {name: '문구 적용', exact: true}).click();
      await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('제목은 비워 둘 수 없어요');
      await page.getByRole('button', {name: '문구 편집 닫기', exact: true}).click();
      await choose(page, '목차', '표지');
      await expect(page.getByRole('button', {name: /^표지 미리보기.*함께하는.*계절/})).toBeVisible();
      await choose(page, '앨범 규격', '가로형');
      await expect(page.getByRole('button', {name: /^표지 미리보기.*함께하는.*계절/})).toBeVisible();
      await snap(page, `${viewport.width}-edited-cover.png`);
      await page.getByRole('button', {name: '무료와 비교', exact: true}).click();
      await expect(page.getByRole('button', {name: '무료 1–2쪽 확대', exact: true})).toBeVisible();
      await snap(page, `${viewport.width}-comparison.png`);
      await page.getByRole('button', {name: '무료 1–2쪽 확대', exact: true}).click();
      await snap(page, `${viewport.width}-comparison-enlarged.png`);
      await page.getByRole('button', {name: '비교 확대 닫기', exact: true}).click();
      await page.getByText('3–4', {exact: true}).click();
      await snap(page, `${viewport.width}-comparison-archive.png`);
      await page.getByRole('button', {name: '비교 사진 숨기기', exact: true}).click();
      await snap(page, `${viewport.width}-comparison-no-photos.png`);
      await choose(page, '비교 규격', '가로형');
      await page.getByRole('button', {name: 'Back', exact: true}).click();
      await expect(page.getByRole('button', {name: /^표지 미리보기.*함께하는.*계절/})).toBeVisible();
      await page.reload();
      await enable(page);
      await page.getByRole('button', {name: '문구 조판', exact: true}).click();
      await expect(star(page, '장면을 여는 문장', true)).toBeVisible();
      await expect.poll(() => savedKeys(page)).toHaveLength(2);
      assert.deepEqual(errors, []);
      assert.deepEqual(failures, []);
      assert.deepEqual(api, []);
      checks.push({viewport, checks: '3 ratios, 3 spreads, copy edit/cancel/overflow guard, gallery navigation, same-photo free comparison, comparison enlargement and photo hiding, recent-first favorites and persistence, no API calls'});
      console.log(`${viewport.width}: typography study passed`);
      await context.close();
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify({checks}, null, 2));
  } finally {await browser.close();}
})().catch(e => {console.error(e); process.exitCode = 1;});
