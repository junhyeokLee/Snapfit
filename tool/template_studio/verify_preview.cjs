const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {PNG} = require('pngjs');

const url = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/qa');
fs.mkdirSync(out, {recursive: true});
const results = [];

function differentPixels(a, b) {
  const first = PNG.sync.read(a), second = PNG.sync.read(b);
  assert.equal(first.width, second.width);
  let changed = 0;
  for (let i = 0; i < first.data.length; i += 4) {
    if (Math.abs(first.data[i] - second.data[i]) + Math.abs(first.data[i + 1] - second.data[i + 1]) + Math.abs(first.data[i + 2] - second.data[i + 2]) > 35) changed++;
  }
  return changed;
}

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    for (const viewport of [{width: 390, height: 844}, {width: 844, height: 390}, {width: 320, height: 568}, {width: 1440, height: 900}]) {
      const page = await browser.newPage({viewport});
      page.setDefaultTimeout(15000);
      const errors = [], apiRequests = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('request', request => {
        if (/api\.openai\.com|api\.anthropic\.com|\.supabase\.co/.test(request.url())) apiRequests.push(request.url());
      });
      await page.goto(url, {waitUntil: 'domcontentloaded'});
      await page.waitForSelector('flt-semantics-placeholder', {state: 'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      const button = (name) => page.getByRole('button', {name, exact: typeof name === 'string'});
      await button('다음 페이지').waitFor();
      await page.waitForTimeout(2500);
      const prefix = `${viewport.width}x${viewport.height}`;
      const cover = await page.screenshot({path: path.join(out, `${prefix}-cover.png`)});
      const bounds = await button(/^표지 미리보기/).boundingBox();
      assert(bounds, 'Cover accessibility bounds missing');
      const pixels = PNG.sync.read(cover), colors = new Set();
      for (let y = Math.ceil(bounds.y + bounds.height * .45); y < bounds.y + bounds.height * .76; y += 2) {
        for (let x = Math.ceil(bounds.x + bounds.width * .16); x < bounds.x + bounds.width * .84; x += 2) {
          const i = (y * pixels.width + x) * 4;
          colors.add(`${pixels.data[i] >> 3},${pixels.data[i + 1] >> 3},${pixels.data[i + 2] >> 3}`);
        }
      }
      assert(colors.size > 150, `Cover photograph not rendered at ${prefix}: only ${colors.size} colors`);
      await button('시안 선택').click();
      await page.getByRole('menuitemcheckbox', {name: '샘플 사진'}).click();
      await page.waitForTimeout(450);
      const empty = await page.screenshot({path: path.join(out, `${prefix}-empty.png`)});
      const photoPixels = differentPixels(cover, empty);
      assert(photoPixels > 3000, `Cover photograph missing at ${prefix}: ${photoPixels}`);
      await button('시안 선택').click();
      await page.getByRole('menuitemcheckbox', {name: '샘플 사진'}).click();
      await button('다음 페이지').click();
      await page.waitForTimeout(400);
      const spread = await page.screenshot({path: path.join(out, `${prefix}-pages.png`)});
      assert(differentPixels(cover, spread) > 5000, `Page did not change at ${prefix}`);
      await button(/^3쪽 선택/).click();
      await page.waitForTimeout(300);
      await button('페이지 확대').click();
      await page.waitForTimeout(400);
      const fit = await page.screenshot({path: path.join(out, `${prefix}-inspection.png`)});
      await button('확대').click();
      await page.waitForTimeout(250);
      const zoom = await page.screenshot({path: path.join(out, `${prefix}-zoom.png`)});
      assert(differentPixels(fit, zoom) > 5000, `Zoom did not change pixels at ${prefix}`);
      await button('화면에 맞추기').click();
      await button('확대 보기 닫기').click();
      await page.waitForTimeout(350);
      assert.equal(await button(/^3쪽 선택/).getAttribute('aria-current'), 'true');
      await page.setViewportSize(viewport.width > viewport.height ? {width: 390, height: 844} : {width: 844, height: 390});
      await page.waitForTimeout(400);
      assert.equal(await button(/^3쪽 선택/).getAttribute('aria-current'), 'true');
      await page.setViewportSize(viewport);
      await button('시안 선택').click();
      await page.getByRole('menuitem', {name: 'AI 결과 화면 · 테스트 문서'}).click();
      await page.waitForTimeout(350);
      await page.screenshot({path: path.join(out, `${prefix}-ai-fixture.png`)});
      await button('디자인 정보').click();
      await page.waitForTimeout(250);
      await button('디자인 정보 닫기').click();
      await button('이 디자인 사용').click();
      await page.waitForTimeout(250);
      assert(await page.getByText('이 화면은 수작업 시안과 테스트 문서로 동작합니다. AI 요청, 앨범 저장, 결제는 실행하지 않습니다.').isVisible());
      await button('확인').click();
      await button('테마 전환').click();
      await page.waitForTimeout(300);
      await page.screenshot({path: path.join(out, `${prefix}-dark.png`)});
      assert.deepEqual(errors, []);
      assert.deepEqual(apiRequests, []);
      results.push({viewport, photoPixels, coverPhotoColors: colors.size, checks: 11, apiRequests: 0, pageErrors: 0});
      console.log(`${prefix}: photos, navigation, thumbnails, zoom, rotation, details, safe demo, dark theme, no API, no errors passed`);
      await page.close();
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify({source: 'Authored specimens and contract fixture, not AI outputs', results}, null, 2));
  } finally {
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
