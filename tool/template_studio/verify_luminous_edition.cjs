const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const chapters = ['도착한 곳, 챙겨 온 것', '골목의 장면과 카페', '해변과 짧은 편지', '사진 한 장, 엽서 한 장'];
const reviewedSpreads = process.env.TEMPLATE_REVIEW_SPREADS
  ? process.env.TEMPLATE_REVIEW_SPREADS.split(',').map(Number)
  : chapters.map((_, i) => i + 1);
assert(reviewedSpreads.length > 0 && reviewedSpreads.every(i => Number.isInteger(i) && i >= 1 && i <= chapters.length));
const out = path.resolve(`output/template-preview/luminous-edition/${process.env.TEMPLATE_REVIEW_SPREADS ? 'browser-focus' : 'browser'}`);
fs.mkdirSync(out, {recursive: true});
async function choose(page, label, item) {
  await page.getByRole('button', {name: label === '시안 선택' ? /시안 선택/ : label, exact: label !== '시안 선택'}).click();
  const target = page.getByRole('menuitem', {name: item, exact: true});
  const viewport = page.viewportSize();
  for (let i = 0; i < 24; i++) {
    const b = await target.count() ? await target.boundingBox() : null;
    const menu = await page.getByRole('menu').boundingBox();
    const top = Math.max(0, menu.y), bottom = Math.min(viewport.height, menu.y + menu.height);
    if (b && b.y >= top && b.y + b.height <= bottom) break;
    await page.mouse.move(menu.x + menu.width / 2, top + (bottom - top) * .7);
    await page.mouse.wheel(0, b && b.y < top ? -220 : 220);
    await page.waitForTimeout(100);
  }
  await target.click();
}
async function shot(page, name) {
  await page.mouse.move(1, 1);
  await page.waitForTimeout(900);
  const png = PNG.sync.read(await page.screenshot({path: path.join(out, name)}));
  const colors = new Set();
  for (let i = 0; i < png.data.length; i += 16) colors.add(`${png.data[i] >> 3},${png.data[i + 1] >> 3},${png.data[i + 2] >> 3}`);
  assert(colors.size > 100, `${name}: empty render`);
}
(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const checks = [];
  try {
    for (const viewport of [{width:390,height:844},{width:844,height:390},{width:1440,height:900}]) {
      const context = await browser.newContext({viewport});
      const page = await context.newPage();
      page.setDefaultTimeout(30000);
      const errors = [], failures = [], api = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => {if (r.status() >= 400) failures.push(r.url());});
      page.on('request', r => {if (/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url());});
      await page.goto(`${root}/?collection=luminous-edition#/luminous-edition`);
      await page.waitForSelector('flt-semantics-placeholder', {state: 'attached', timeout:60000});
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      await expect(page.getByRole('button', {name: /^표지 미리보기/})).toBeVisible({timeout: 20000});
      await choose(page, '판본 선택', '승인 8쪽 기준본');
      await expect.poll(() => page.locator('body').ariaSnapshot(), {timeout:20000}).toContain('디자인 승인 · 미등록');
      for (const ratio of ['세로형', '정사각형', '가로형']) {
        await choose(page, '앨범 규격', ratio);
        await choose(page, '목차', '표지');
        await shot(page, `${viewport.width}-${ratio}-cover.png`);
        for (const [i, title] of chapters.entries()) {
          if (!reviewedSpreads.includes(i + 1)) continue;
          await choose(page, '목차', `${i * 2 + 1}–${i * 2 + 2} / ${title}`);
          await expect(page.getByRole('button', {name: new RegExp(`^${i * 2 + 1}쪽 미리보기`)})).toBeVisible();
          await shot(page, `${viewport.width}-${ratio}-spread-${i + 1}.png`);
          if (viewport.width < 600) {
            await page.getByRole('button', {name:'다음 페이지', exact:true}).click();
            await expect(page.getByRole('button', {name: new RegExp(`^${i * 2 + 2}쪽 미리보기`)})).toBeVisible();
            await shot(page, `${viewport.width}-${ratio}-page-${i * 2 + 2}.png`);
          }
        }
      }
      await choose(page, '목차', '표지');
      await page.getByRole('button', {name:'문구 편집', exact:true}).click();
      await page.getByRole('textbox', {name:/^아랫줄 앞/}).click();
      await page.waitForTimeout(200);
      await page.locator('input:focus,textarea:focus').fill('반짝인');
      await page.waitForTimeout(150);
      await page.getByRole('button', {name:'문구 적용', exact:true}).click();
      await expect(page.getByRole('button', {name:/^표지 미리보기.*반짝인/})).toBeVisible();
      await shot(page, `${viewport.width}-edited-outline.png`);
      await page.getByRole('button', {name:'꾸밈 재료', exact:true}).click();
      await shot(page, `${viewport.width}-materials.png`);
      await page.getByRole('switch', {name:'블루 포켓 카메라 즐겨찾기 추가', exact:true}).click();
      await expect(page.getByRole('switch', {name:'블루 포켓 카메라 즐겨찾기 해제', exact:true})).toBeVisible();
      await page.getByRole('button', {name:/블루 포켓 카메라 확대/}).click();
      await expect(page.getByRole('heading', {name:'블루 포켓 카메라', exact:true})).toBeVisible();
      await shot(page, `${viewport.width}-material-enlarged.png`);
      await page.getByRole('button', {name:'Back', exact:true}).click();
      await page.getByRole('tab', {name:'프레임', exact:true}).click();
      await shot(page, `${viewport.width}-frames.png`);
      await page.getByRole('tab', {name:'문구', exact:true}).click();
      await shot(page, `${viewport.width}-phrases.png`);
      await page.getByRole('button', {name:'Back', exact:true}).click();
      await expect(page.getByRole('button', {name:/^표지 미리보기.*반짝인/})).toBeVisible();
      await page.getByLabel('둘만의 여행 즐겨찾기 추가', {exact:true}).click();
      await expect(page.getByLabel('둘만의 여행 즐겨찾기 해제', {exact:true})).toBeVisible();
      await page.getByRole('button', {name:'무료와 비교', exact:true}).click();
      await shot(page, `${viewport.width}-free-comparison.png`);
      await page.getByRole('button', {name:'같은 사진으로 비교', exact:true}).click();
      await page.mouse.move(1, 1);
      await expect(page.getByRole('button', {name:/원본 사진으로 비교/})).toBeVisible();
      await shot(page, `${viewport.width}-matched-photos.png`);
      await expect.poll(() => page.locator('body').ariaSnapshot(), {timeout:20000}).toContain('함께여서 좋은 날');
      await page.getByRole('button', {name:'Back', exact:true}).click();
      await expect(page.getByRole('button', {name:/^표지 미리보기.*반짝인/})).toBeVisible();
      await choose(page, '시안 선택', '둘만의 여행 · 20쪽 보관본');
      await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('20쪽 보관본');
      await expect(page.getByRole('button', {name:'문구 편집', exact:true})).toHaveCount(0);
      for (const ratio of ['세로형', '정사각형', '가로형']) {
        await choose(page, '앨범 규격', ratio);
        await choose(page, '목차', '19–20 / 여행을 꺼내 보는 날');
        await expect(page.getByRole('button', {name: /^19쪽 미리보기/})).toBeVisible();
        await shot(page, `${viewport.width}-archive-${ratio}.png`);
      }
      await choose(page, '시안 선택', '함께여서 좋은 날');
      await expect.poll(() => page.locator('body').ariaSnapshot(), {timeout:20000}).toContain('무료 · 표지 + 내지 24쪽');
      assert.deepEqual(errors, []); assert.deepEqual(failures, []); assert.deepEqual(api, []);
      checks.push({viewport, ratios:3, pages:chapters.length * 2 + 1, reviewedSpreads, archivePages:21, archiveReadOnly:true, editedTitle:true, materials:true, materialFavorite:true, materialEnlargement:true, favorite:true, freeComparison:true, freeRoute:true});
      console.log(`${viewport.width}: candidate passed`);
      await context.close();
    }
    fs.writeFileSync(path.join(out,'report.json'), JSON.stringify({checks}, null, 2));
  } finally {await browser.close();}
})().catch(e => {console.error(e); process.exitCode = 1;});
