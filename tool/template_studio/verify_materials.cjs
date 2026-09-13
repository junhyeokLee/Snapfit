const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {PNG} = require('pngjs');

const url = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323/';
const out = path.resolve('output/template-preview/material-browser');
fs.mkdirSync(out, {recursive: true});
const categories = {
  '종이': ['수제지 조각', '코튼 페이퍼', '블러시 한지', '아카이브 노트', '트레이싱 페이퍼'],
  '스티커': ['코스모스 압화', '세이지 리본', '시트러스 프린트', '메모리 티켓', '보태니컬 우표'],
  '테이프': ['핀스트라이프', '로즈 체크', '잉크 도트'],
};
const ratios = {
  '수제지 조각': 1388 / 1133, '코튼 페이퍼': .82, '블러시 한지': 1.28,
  '아카이브 노트': .8, '트레이싱 페이퍼': .84, '코스모스 압화': 2 / 3,
  '세이지 리본': 1, '시트러스 프린트': 1, '메모리 티켓': 2.15,
  '보태니컬 우표': .76, '핀스트라이프': 3.8, '로즈 체크': 3.8, '잉크 도트': 3.8,
};

function pixels(buffer, bounds) {
  const png = PNG.sync.read(buffer), colors = new Set();
  let content = 0;
  for (let y = Math.ceil(bounds.y); y < Math.min(png.height, bounds.y + bounds.height); y++) {
    for (let x = Math.ceil(bounds.x); x < Math.min(png.width, bounds.x + bounds.width); x++) {
      const i = (y * png.width + x) * 4;
      colors.add(`${png.data[i]},${png.data[i + 1]},${png.data[i + 2]}`);
      if (png.data[i] + png.data[i + 1] + png.data[i + 2] > 200) content++;
    }
  }
  return {colors: colors.size, content};
}

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const results = [];
  try {
    for (const viewport of [{width: 390, height: 844}, {width: 844, height: 390},
      {width: 320, height: 568}, {width: 1440, height: 900}]) {
      const page = await browser.newPage({viewport});
      const errors = [], requests = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => {if (m.type() === 'error') errors.push(m.text());});
      page.on('request', r => {if (/api\.openai\.com|api\.anthropic\.com|\.supabase\.co/.test(r.url())) requests.push(r.url());});
      await page.goto(url);
      await page.waitForSelector('flt-semantics-placeholder', {state: 'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      const button = name => page.getByRole('button', {name, exact: typeof name === 'string'});
      await button('종이·스티커').click();
      await page.getByRole('tab', {name: '새 컬렉션', exact: true}).waitFor();
      await page.waitForTimeout(500);
      await page.screenshot({path: path.join(out, `${viewport.width}-collection.png`)});
      for (const [category, labels] of Object.entries(categories)) {
        await page.getByRole('tab', {name: category, exact: true}).click();
        await page.waitForTimeout(300);
        for (const label of labels) {
          const tile = button(new RegExp(`${label} 추가$`));
          await tile.scrollIntoViewIfNeeded();
          await tile.click();
          const art = page.getByLabel(`${label} 크게 보기`, {exact: true})
              .or(page.getByText(`${label} 크게 보기`, {exact: true}).locator('..'));
          await art.waitFor();
          await button('잉크').click();
          await page.mouse.move(1, 1);
          await page.waitForTimeout(300);
          const box = await art.boundingBox();
          assert(box && box.width > 25 && box.height > 25, `${label}: collapsed artwork`);
          assert(Math.abs(box.width / box.height - ratios[label]) < .02,
              `${label}: material aspect changed ${JSON.stringify(box)}`);
          assert(box.x >= 0 && box.y >= 48 && box.x + box.width <= viewport.width + 1 &&
              box.y + box.height <= viewport.height, `${label}: clipped artwork`);
          const dark = await page.screenshot({path: path.join(out, `${viewport.width}-${label}-ink.png`)});
          const variation = pixels(dark, box);
          assert(variation.colors > 20, `${label}: blank artwork, ${JSON.stringify(variation)}`);
          await button('화이트').click();
          await page.mouse.move(1, 1);
          await page.waitForTimeout(300);
          await page.screenshot({path: path.join(out, `${viewport.width}-${label}-white.png`)});
          results.push({viewport, category, label, box, ...variation});
        }
      }
      await button('Back').click();
      await button('테마 전환').click();
      await button('종이·스티커').click();
      await page.waitForTimeout(500);
      await page.screenshot({path: path.join(out, `${viewport.width}-dark-picker.png`)});
      assert.deepEqual(errors, []);
      assert.deepEqual(requests, []);
      await page.close();
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify({results}, null, 2));
    console.log(`${results.length} material/viewport combinations passed, light/ink pixels, navigation, no external AI requests.`);
  } finally {await browser.close();}
})().catch(e => {console.error(e); process.exitCode = 1;});
