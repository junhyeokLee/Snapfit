const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {PNG} = require('pngjs');

const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/frames');
const names = ['캡슐 컷', '대각 라운드', '물결 컷', '티켓 컷', '갤러리 매트', '수제지 프레임', '인화지 프레임', '필름 프레임'];
fs.mkdirSync(out, {recursive: true});

function colors(bytes, box) {
  const png = PNG.sync.read(bytes), result = new Set();
  for (let y = Math.ceil(box.y); y < box.y + box.height - 1; y += 2) {
    for (let x = Math.ceil(box.x); x < box.x + box.width - 1; x += 2) {
      const i = (y * png.width + x) * 4;
      result.add(`${png.data[i] >> 3},${png.data[i + 1] >> 3},${png.data[i + 2] >> 3}`);
    }
  }
  return result.size;
}

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const results = [];
  try {
    for (const viewport of [{width: 390, height: 844}, {width: 844, height: 390}, {width: 1440, height: 900}]) {
      const page = await browser.newPage({viewport});
      const errors = [], requests = [];
      page.on('pageerror', error => errors.push(error.message));
      page.on('request', request => {
        if (/api\.openai\.com|api\.anthropic\.com|\.supabase\.co/.test(request.url())) requests.push(request.url());
      });
      await page.goto(`${root}/?frames=true`);
      await page.waitForSelector('flt-semantics-placeholder', {state: 'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
      const button = name => page.getByRole('button', {name: new RegExp(`^${name}(?:$|\\s)`)});
      const artwork = name => page.getByRole('img', {name: `${name} 크게 보기`, exact: true});
      await artwork('수제지 프레임').waitFor();

      async function scrollTo(name, direction = 1) {
        for (let i = 0; i < 15; i++) {
          const item = button(name);
          const box = await item.count() ? await item.first().boundingBox() : null;
          if (box && box.y >= (viewport.width > 650 ? 95 : 430) && box.y + box.height <= viewport.height - 10) return item.first();
          await page.mouse.move(viewport.width - 80, viewport.height - 75);
          await page.mouse.wheel(0, direction * 140);
          await page.waitForTimeout(150);
        }
        throw new Error(`Could not reveal ${name} at ${viewport.width}`);
      }

      for (const [format, ratio] of [['세로', 14.5 / 19.4], ['정사각', 1], ['가로', 19.4 / 14.5]]) {
        await button(format).click();
        await page.mouse.move(viewport.width - 80, viewport.height - 75);
        await page.mouse.wheel(0, -3000);
        await page.waitForTimeout(220);
        for (const name of names) {
          await (await scrollTo(name)).click();
          await artwork(name).waitFor();
          await page.waitForTimeout(200);
          const box = await artwork(name).boundingBox();
          assert(Math.abs(box.width / box.height - ratio) < .02, `${name}: album ratio changed`);
          assert(box.x >= 0 && box.y >= 48 && box.x + box.width <= viewport.width && box.y + box.height <= viewport.height);
          const bytes = await page.screenshot({path: path.join(out, `${viewport.width}-${format}-${name}.png`)});
          const variation = colors(bytes, box);
          assert(variation > 140, `${name}: photo missing (${variation} colors)`);
          results.push({viewport, format, name, box, colors: variation});
        }
      }
      await button('실행 취소').click();
      await artwork('인화지 프레임').waitFor();
      await button('다시 실행').click();
      await artwork('필름 프레임').waitFor();
      await button('여행의 풍경').click();
      await button('차콜 배경').click();
      await page.waitForTimeout(350);
      await page.screenshot({path: path.join(out, `${viewport.width}-film-photo-replaced.png`)});
      await button('편집기 프레임 선택창').click();
      await button('닫기').waitFor();
      await page.waitForTimeout(350);
      await page.screenshot({path: path.join(out, `${viewport.width}-editor-picker.png`)});
      await button('캡슐 컷').click();
      await artwork('캡슐 컷').waitFor();
      await button('편집기 프레임 선택창').click();
      await button('닫기').click();
      await artwork('캡슐 컷').waitFor();
      assert.deepEqual(errors, []);
      assert.deepEqual(requests, []);
      await page.close();
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify({results, scope: 'Authored frames; no live AI or payment'}, null, 2));
    console.log(`${results.length} frame/ratio/viewport combinations passed, plus undo, redo, photo change and real picker.`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
