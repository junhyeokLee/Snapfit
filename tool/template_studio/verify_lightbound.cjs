const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');

const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const collection = process.argv[2] || 'lightbound';
const presets = {
  lightbound: {first: '서로에게 닿은 날', middle: '함께한 얼굴들', last: '다음의 우리', textOnly: [18, 24]},
  journey: {first: '출발의 문장', middle: '시장에서 고른 것', last: '여행 다음의 날', textOnly: [14, 20, 24]},
  'small-days': {first: '오늘의 기분', middle: '함께 먹는 오후', last: '내일도 이만큼', textOnly: [8, 16, 20, 24]},
};
const preset = presets[collection];
assert(preset, `Unknown draft: ${collection}`);
const out = path.resolve(`output/template-preview/${collection}/browser`);
const lastPage = 24;
const textOnlyPages = new Set(preset.textOnly);
fs.mkdirSync(out, {recursive: true});

function colorCount(bytes, box) {
  const png = PNG.sync.read(bytes), colors = new Set();
  for (let y = Math.max(0, Math.ceil(box.y)); y < Math.min(png.height, box.y + box.height); y += 2) {
    for (let x = Math.max(0, Math.ceil(box.x)); x < Math.min(png.width, box.x + box.width); x += 2) {
      const i = (y * png.width + x) * 4;
      colors.add(`${png.data[i] >> 3},${png.data[i + 1] >> 3},${png.data[i + 2] >> 3}`);
    }
  }
  return colors.size;
}

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const results = [];
  try {
    for (const viewport of [{width: 390, height: 844}, {width: 844, height: 390}, {width: 1440, height: 900}]) {
      const page = await browser.newPage({viewport});
      const errors = [], api = [], failedAssets = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('request', r => { if (/api\.openai\.com|api\.anthropic\.com|\.supabase\.co/.test(r.url())) api.push(r.url()); });
      page.on('response', r => { if (r.status() >= 400 && /assets\//.test(r.url())) failedAssets.push(r.url()); });
      await page.goto(`${root}/?collection=${collection}`);
      await page.waitForSelector('flt-semantics-placeholder', {state: 'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      const button = name => page.getByRole('button', {name: typeof name === 'string' ? new RegExp(`^${name}`) : name});
      await button('문구 편집').waitFor();
      const wide = viewport.width > viewport.height;
      for (const [format, ratio] of [['세로형', 14.5 / 19.4], ['정사각형', 1], ['가로형', 19.4 / 14.5]]) {
        await button('앨범 규격').click();
        await page.getByRole('menuitem', {name: format, exact: true}).click();
        // Use the overview to return to the cover without scrolling a hidden rail.
        await button('전체 펼침 보기').click();
        await button('표지 펼치기').click();
        const stem = `${viewport.width}-${format}`;
        const frames = [];
        for (let index = 0; index <= lastPage; index += index === 0 ? 1 : (wide ? 2 : 1)) {
          const preview = button(index === 0 ? '표지 미리보기' : `${index}쪽 미리보기`);
          await preview.waitFor();
          await page.waitForTimeout(450);
          const bounds = await preview.boundingBox();
          assert(bounds.x >= 0 && bounds.y >= 0 && bounds.x + bounds.width <= viewport.width + 1 && bounds.y + bounds.height <= viewport.height + 1, `${stem}/${index}: clipped canvas`);
          assert(Math.abs(bounds.width / bounds.height - ratio) < .025, `${stem}/${index}: physical aspect changed`);
          let bytes = await page.screenshot();
          let colors = colorCount(bytes, bounds);
          if (!textOnlyPages.has(index)) {
            await expect.poll(async () => {
              bytes = await page.screenshot();
              return colors = colorCount(bytes, bounds);
            }, {timeout: 10000, message: `${stem}/${index}: photograph did not render`}).toBeGreaterThan(80);
          }
          fs.writeFileSync(path.join(out, `${stem}-${index}.png`), bytes);
          if (wide && index > 0) {
            const right = await button(`${index + 1}쪽 미리보기`).boundingBox();
            assert(Math.abs(right.x - (bounds.x + bounds.width)) < 1, `${stem}/${index}: spread separated`);
            assert(Math.abs(right.y - bounds.y) < 1, `${stem}/${index}: spread alignment`);
          }
          frames.push({index, bounds, colors});
          if (index + (wide && index > 0 ? 2 : 1) <= lastPage) await button('다음 페이지').click();
        }
        assert(!(await button('다음 페이지').count()) || !(await button('다음 페이지').isEnabled()));
        await button('페이지 확대').click();
        await button('확대 보기 닫기').waitFor();
        await button('확대 보기 닫기').click();
        await button('전체 펼침 보기').click();
        await page.screenshot({path: path.join(out, `${stem}-overview.png`)});
        await button(`01 / ${preset.first} 펼치기`).click();
        await button('1쪽 미리보기').waitFor();
        await button('샘플 사진 숨기기').click();
        await button('샘플 사진 보이기').waitFor();
        await page.screenshot({path: path.join(out, `${stem}-empty.png`)});
        await button('샘플 사진 보이기').click();
        await button('1쪽 미리보기').waitFor();
        await button('목차').click();
        await page.getByRole('menuitem', {name: `23–24 / ${preset.last}`, exact: true}).click();
        await button('23쪽 미리보기').waitFor();
        await button('목차').click();
        await page.getByRole('menuitem', {name: `11–12 / ${preset.middle}`, exact: true}).click();
        await button('11쪽 미리보기').waitFor();
        results.push({viewport, format, frames});
        console.log(`${stem}: cover, all 24 pages, spread bounds, contents navigation, overview, zoom, photo toggle passed`);
      }

      await button('문구 편집').click();
      await page.getByRole('textbox').first().click();
      await page.getByRole('textbox').first().fill('김수연');
      await button('문구 적용').click();
      await button('문구 편집').click();
      // Flutter populates its HTML editing input only after it gains focus.
      await page.getByRole('textbox').first().click();
      await expect(page.getByRole('textbox').first()).toHaveValue('김수연');
      await page.getByRole('textbox').first().fill('취소할 이름');
      await button('문구 편집 닫기').click();
      await button('문구 편집').click();
      await page.getByRole('textbox').first().click();
      await expect(page.getByRole('textbox').first()).toHaveValue('김수연');
      await page.getByRole('textbox').first().fill('');
      await button('문구 적용').click();
      await expect(page.locator('span').getByText('내용을 입력해 주세요.', {exact: true})).toBeVisible();
      await page.screenshot({path: path.join(out, `${viewport.width}-copy-validation.png`)});
      await button('문구 편집 닫기').click();
      assert.deepEqual(errors, []);
      assert.deepEqual(api, []);
      assert.deepEqual(failedAssets, []);
      await page.close();
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify({source: 'Independently authored free collection; not a paid item or AI generation', results}, null, 2));
    console.log(`${results.length} physical-format/viewport combinations passed.`);
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
