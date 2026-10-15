const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/sale-and-garden');

(async () => {
  fs.mkdirSync(out, {recursive: true});
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const report = [];
  try {
    for (const viewport of [{width:390,height:844}, {width:844,height:390}, {width:1440,height:1000}]) {
      for (const query of ['catalog=store', 'collection=garden-letters']) {
        const page = await browser.newPage({viewport});
        const errors = [];
        page.on('pageerror', e => errors.push(e.message));
        await page.goto(`${root}/?${query}`);
        const placeholder = page.locator('flt-semantics-placeholder');
        await placeholder.waitFor({state:'attached'});
        await placeholder.evaluate(e => e.click());
        const garden = query.startsWith('collection');
        await expect.poll(() => page.locator('body').ariaSnapshot())
          .toContain(garden ? '정원의 편지' : '51종');
        await page.waitForTimeout(1800);
        await page.screenshot({path: path.join(out, `${viewport.width}-${garden ? 'garden-cover' : 'store'}.png`)});
        if (garden) {
          await page.getByRole('button', {name:'다음 페이지', exact:true}).click();
          await page.waitForTimeout(600);
          await page.screenshot({path: path.join(out, `${viewport.width}-garden-opening.png`)});
          await page.getByRole('button', {name:'전체 펼침 보기', exact:true}).click();
          await page.waitForTimeout(800);
          await page.screenshot({path: path.join(out, `${viewport.width}-garden-overview.png`)});
        }
        assert.deepEqual(errors, []);
        report.push({viewport, query, errors});
        await page.close();
      }
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
