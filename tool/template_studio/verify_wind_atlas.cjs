const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');

const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/wind-atlas/browser');
fs.mkdirSync(out, {recursive: true});
const results = [];

function colors(bytes) {
  const png = PNG.sync.read(bytes), unique = new Set();
  for (let i = 0; i < png.data.length; i += 16) {
    unique.add(`${png.data[i] >> 3},${png.data[i + 1] >> 3},${png.data[i + 2] >> 3}`);
  }
  return unique.size;
}

async function choose(page, name, option, role = 'menuitem') {
  await page.getByRole('button', {name, exact: true}).click();
  const item = page.getByRole(role, {name: option, exact: true});
  for (let i = 0; i < 12; i++) {
    if (await item.isVisible()) {
      await item.click();
      await expect(page.getByRole('menu')).toHaveCount(0);
      return;
    }
    const menu = await page.getByRole('menu').boundingBox();
    assert(menu, 'Popup menu must remain open');
    await page.mouse.move(menu.x + menu.width / 2, menu.y + menu.height / 2);
    await page.mouse.wheel(0, 70);
    await page.waitForTimeout(150);
  }
  throw new Error(`Menu option unreachable: ${option}`);
}

async function snapshot(page, name) {
  await page.mouse.move(1, 1);
  await page.waitForTimeout(600);
  const bytes = await page.screenshot({path: path.join(out, name)});
  assert(colors(bytes) > 150, `${name}: rendered page is blank`);
}

(async () => {
  for (const file of ['coast_watercolor', 'lemon_botanical']) {
    const asset = PNG.sync.read(fs.readFileSync(`assets/templates/premium_wind_atlas/${file}.png`));
    let transparent = 0, dense = 0, partial = 0;
    for (let i = 3; i < asset.data.length; i += 4) {
      if (asset.data[i] === 0) transparent++;
      // Watercolor pigment is intentionally slightly translucent (alpha 250+).
      else if (asset.data[i] >= 240) dense++;
      else partial++;
    }
    assert(transparent > asset.width * asset.height * .1);
    assert(dense > asset.width * asset.height * .1);
    assert(asset.width >= 1024 && asset.height >= 1024);
    results.push({asset: file, width: asset.width, height: asset.height, transparent, dense, partial});
  }
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    for (const viewport of [{width: 390, height: 844}, {width: 844, height: 390}, {width: 1440, height: 900}]) {
      const page = await browser.newPage({viewport});
      page.setDefaultTimeout(15000);
      const errors = [], failures = [], api = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => { if (r.status() >= 400) failures.push(r.url()); });
      page.on('request', r => { if (/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url()); });
      await page.goto(`${root}/?collection=wind-atlas#/wind-atlas`);
      await page.waitForSelector('flt-semantics-placeholder', {state: 'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      await expect(page.getByRole('button', {name: '표지 디자인', exact: true})).toBeVisible();
      await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('무료 · 표지 + 내지 32쪽');
      assert(!(await page.locator('body').ariaSnapshot()).includes('유료 시안'));
      for (const cover of ['해안 화보', '보태니컬 에디션', '수집가의 표지']) {
        await choose(page, '표지 디자인', cover, 'menuitemcheckbox');
        for (const ratio of ['세로형', '정사각형', '가로형']) {
          await choose(page, '앨범 규격', ratio);
          const artwork = page.getByRole('button', {name: /^표지 미리보기/});
          await expect(artwork).toBeVisible();
          await expect.poll(async () => colors(await artwork.screenshot())).toBeGreaterThan(100);
          const b = await artwork.boundingBox();
          assert(b.x >= 0 && b.y >= 0 && b.x + b.width <= viewport.width + 1 && b.y + b.height <= viewport.height + 1);
          await snapshot(page, `${viewport.width}-${cover}-${ratio}.png`);
          results.push({viewport, cover, ratio});
        }
      }
      await choose(page, '표지 디자인', '해안 화보', 'menuitemcheckbox');
      await choose(page, '앨범 규격', '정사각형');
      await page.getByRole('button', {name: '다음 페이지', exact: true}).click();
      await expect(page.getByRole('button', {name: /^1쪽 미리보기/})).toBeVisible();
      await snapshot(page, `${viewport.width}-opening.png`);
      await page.getByRole('button', {name: '전체 펼침 보기', exact: true}).click();
      await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('16 / 다음 여행을 위한 여백');
      await snapshot(page, `${viewport.width}-overview.png`);
      await page.getByRole('button', {name: '책으로 보기', exact: true}).click();

      await page.getByRole('button', {name: '문구 편집', exact: true}).click();
      await page.getByRole('textbox', {name: /^여행지/}).click();
      const input = page.locator('input:focus, textarea:focus');
      await expect(input).toBeFocused();
      await input.fill('우리의 여름');
      await page.getByRole('button', {name: '문구 적용', exact: true}).click();
      await expect(page.getByRole('button', {name: '문구 적용', exact: true})).toHaveCount(0);
      await choose(page, '표지 디자인', '보태니컬 에디션', 'menuitemcheckbox');
      await expect(page.getByRole('button', {name: /^표지 미리보기.*우리의 여름/})).toBeVisible();
      await choose(page, '앨범 규격', '세로형');
      await expect(page.getByRole('button', {name: /^표지 미리보기.*우리의 여름/})).toBeVisible();
      results.push({viewport, action: 'edit survives cover and ratio change; cover selection returns to cover'});

      await page.getByRole('button', {name: '문구 편집', exact: true}).click();
      await page.getByRole('textbox', {name: /^여행지/}).click();
      await expect(page.locator('input:focus, textarea:focus')).toHaveValue('우리의 여름');
      await page.getByRole('button', {name: '문구 편집 닫기', exact: true}).click();
      await choose(page, '목차', '3–4 / 도착의 감각');
      const photoPage = page.getByRole('button', {name: /^4쪽 미리보기/});
      if (viewport.width < 600) {
        await page.getByRole('button', {name: '다음 페이지', exact: true}).click();
      }
      await expect(photoPage).toBeVisible();
      const initial = await photoPage.screenshot();
      await choose(page, '사진 교체 확인', '인물 사진');
      await expect.poll(async () => Buffer.compare(initial, await photoPage.screenshot())).not.toBe(0);
      await snapshot(page, `${viewport.width}-portrait-replacement.png`);
      await page.getByRole('button', {name: '샘플 사진 숨기기', exact: true}).click();
      await expect.poll(async () => colors(await photoPage.screenshot())).toBeLessThan(100);
      await snapshot(page, `${viewport.width}-empty-slots.png`);
      await page.getByRole('button', {name: '샘플 사진 보이기', exact: true}).click();
      await choose(page, '사진 교체 확인', '어두운 저녁 사진');
      await snapshot(page, `${viewport.width}-dark-replacement.png`);
      results.push({viewport, action: 'editable photo replacement, empty slots, dark photo and preserved artwork'});
      assert.deepEqual(errors, []);
      assert.deepEqual(failures, []);
      assert.deepEqual(api, []);
      fs.writeFileSync(path.join(out, `${viewport.width}-semantics.txt`), await page.locator('body').ariaSnapshot());
      console.log(`${viewport.width}: covers, ratios, navigation, copy retention, and photo replacement passed`);
      await page.close();
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify({results}, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
