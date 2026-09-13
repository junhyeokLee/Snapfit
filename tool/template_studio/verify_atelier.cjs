const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/atelier/browser');
const sets = ['보태니컬', '여행 기록', '작은 축하', '페이퍼 아카이브'];
const frames = ['이중 매트', '사진 코너', '타원 매트', '린넨 매트', '에어메일 엽서', '우표 인화지'];
fs.mkdirSync(out, {recursive: true});

function colors(bytes) {
  const png = PNG.sync.read(bytes), unique = new Set();
  for (let i = 0; i < png.data.length; i += 16) {
    unique.add(`${png.data[i] >> 3},${png.data[i + 1] >> 3},${png.data[i + 2] >> 3}`);
  }
  return unique.size;
}

async function reach(page, locator) {
  const v = page.viewportSize();
  for (let i = 0; i < 20; i++) {
    const b = await locator.boundingBox();
    if (b && b.y >= 0 && b.y + b.height < v.height && b.x >= 0 && b.x + b.width <= v.width) return;
    await page.mouse.move(v.width - 16, v.height * .72);
    await page.mouse.wheel(0, b ? Math.max(-160, Math.min(160, b.y - v.height * .6)) : 160);
    await page.waitForTimeout(120);
  }
  throw new Error('Control is unreachable');
}

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const results = [];
  try {
    for (const viewport of [{width:390,height:844}, {width:844,height:390}, {width:1440,height:900}]) {
      const page = await browser.newPage({viewport});
      page.setDefaultTimeout(15000);
      const errors = [], failures = [], api = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => { if (r.status() >= 400) failures.push(r.url()); });
      page.on('request', r => { if (/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url()); });
      await page.goto(`${root}/?studio=atelier#/atelier`);
      await page.waitForSelector('flt-semantics-placeholder', {state:'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('소재 스튜디오');
      fs.writeFileSync(path.join(out, `${viewport.width}-semantics.txt`), await page.locator('body').ariaSnapshot());
      for (let i = 0; i < sets.length; i++) {
        const control = page.getByRole('checkbox', {name: sets[i], exact:true});
        await control.click();
        const artwork = page.getByRole('img', {name:`${sets[i]} 조합 미리보기`});
        await expect(artwork).toBeVisible();
        for (const ratio of ['세로', '정사각', '가로']) {
          await page.getByRole('button', {name:ratio, exact:true}).click();
          await expect.poll(async () => colors(await artwork.screenshot())).toBeGreaterThan(150);
          const box = await artwork.boundingBox();
          assert(box.x >= 0 && box.y >= 0 && box.x + box.width <= viewport.width + 1 && box.y + box.height <= viewport.height);
          await page.screenshot({path:path.join(out, `${viewport.width}-set-${i}-${ratio}.png`)});
          results.push({viewport, set:sets[i], ratio});
        }
      }
      const artwork = page.getByRole('img', {name:/조합 미리보기/});
      const before = await artwork.screenshot();
      await page.getByRole('button', {name:'사진 교체'}).click();
      await expect.poll(async () => Buffer.compare(before, await artwork.screenshot())).not.toBe(0);
      results.push({viewport, action:'photo replacement'});
      for (const frame of frames) {
        const control = page.getByRole('button', {name:`${frame} 적용`, exact:true});
        await reach(page, control);
        await control.click();
        await expect.poll(async () => colors(await artwork.screenshot())).toBeGreaterThan(150);
        results.push({viewport, frame});
      }
      await page.getByRole('tab', {name:'소재', exact:true}).click();
      const sticker = page.getByRole('button', {name:'로즈 실크 리본 적용', exact:true});
      await reach(page, sticker);
      await sticker.click();
      await page.getByRole('tab', {name:'문구', exact:true}).click();
      await page.getByRole('button', {name:'우리가 서로의 집이 된 날 적용', exact:true}).click();
      await page.getByRole('button', {name:'문구 수정'}).click();
      const textbox = page.getByRole('textbox');
      await textbox.click();
      const input = page.locator('textarea');
      await expect(input).toBeFocused();
      await expect(input).toHaveValue('우리가 서로의\n집이 된 날');
      await input.fill('오늘의 기록을\n우리의 말로 남겨요');
      await page.getByRole('button', {name:'적용', exact:true}).click();
      await expect(page.getByRole('dialog')).toHaveCount(0);
      results.push({viewport, action:'sticker, phrase and custom copy'});
      await page.screenshot({path:path.join(out, `${viewport.width}-edited.png`)});
      assert.deepEqual(errors, []);
      assert.deepEqual(failures, []);
      assert.deepEqual(api, []);
      console.log(`${viewport.width}: compositions, ratios, frames, photo, sticker and editable copy passed`);
      await page.close();
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify({results}, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
