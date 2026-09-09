const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const fullVow = process.env.REVIEW_EDITION === 'vow-keepsake-20';
const ids = fullVow ? ['vow-keepsake-20'] : ['vow-keepsake', 'daily-cabinet', 'first-year-keepsake', 'table-stories', 'two-tickets', 'walk-and-nap'];
const studies = ids.map(id => JSON.parse(fs.readFileSync(`output/template-preview/${id}/square/document.json`, 'utf8')));
const out = path.resolve(`output/template-preview/${fullVow ? 'vow-keepsake-20' : 'heirloom-studies'}/browser`);
fs.mkdirSync(out, {recursive:true});

async function open(page, route) {
  const query = route === 'premium-studies' ? 'catalog=premium' : `collection=${route}`;
  await page.goto(`${root}/?${query}&review=heirloom#/${route}`);
  await page.waitForSelector('flt-semantics-placeholder', {state:'attached', timeout:60000});
  await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
  await expect.poll(() => page.locator('body').ariaSnapshot(), {timeout:60000}).not.toBe('');
}
async function choose(page, label, item) {
  await page.getByRole('button', {name:label, exact:true}).click();
  const target = page.getByRole('menuitem', {name:item, exact:true});
  for (let i = 0; i < 20; i++) {
    const b = await target.count() ? await target.boundingBox() : null;
    const menu = await page.getByRole('menu').boundingBox();
    const bottom = Math.min(page.viewportSize().height, menu.y + menu.height);
    if (b && b.y >= Math.max(0,menu.y) && b.y + b.height <= bottom) break;
    await page.mouse.move(menu.x + menu.width / 2, Math.max(0,menu.y) + (bottom - Math.max(0,menu.y)) * .7);
    await page.mouse.wheel(0, b && b.y < menu.y ? -200 : 200);
    await page.waitForTimeout(100);
  }
  await target.click();
}
async function shot(page, name) {
  await page.mouse.move(1,1);
  await page.waitForTimeout(900);
  const png = PNG.sync.read(await page.screenshot({path:path.join(out, name + '.png')}));
  const colors = new Set();
  for (let i = 0; i < png.data.length; i += 16) colors.add(`${png.data[i] >> 3},${png.data[i+1] >> 3},${png.data[i+2] >> 3}`);
  assert(colors.size > 100, `${name}: empty canvas`);
}
async function revealMaterial(page, target, direction) {
  for (let i = 0; i < 25; i++) {
    // Favoriting reorders and temporarily unmounts cells in Flutter's lazy grid.
    const b = await target.boundingBox({timeout:300}).catch(() => null);
    if (b && b.y >= 115 && b.y + b.height <= page.viewportSize().height) return;
    await page.mouse.move(1100,650);
    await page.mouse.wheel(0,550 * direction);
    await page.waitForTimeout(200);
  }
  throw new Error('Material did not enter the visible gallery');
}

(async () => {
  const browser = await chromium.launch({channel:'chrome', headless:true});
  const checks = [];
  try {
    for (const [width,height,ratio] of [[390,844,'세로형'],[844,390,'가로형'],[1440,900,'정사각형']]) {
      if (process.env.REVIEW_WIDTH && width !== Number(process.env.REVIEW_WIDTH)) continue;
      const context = await browser.newContext({viewport:{width,height}});
      const page = await context.newPage();
      page.setDefaultTimeout(30000);
      const errors = [], failures = [], api = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => {if (r.status() >= 400) failures.push(r.url());});
      page.on('request', r => {if (/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url());});
      try {
        await open(page, 'premium-studies');
        await expect(page.getByRole('heading', {name:'유료 템플릿 시안', exact:true})).toBeVisible();
        await shot(page, `${width}-catalog`);
        await page.getByRole('checkbox', {name:'웨딩',exact:true}).click();
        await expect(page.getByLabel('약속을 묶은 책 즐겨찾기 추가', {exact:true})).toBeVisible();
        await page.getByLabel('약속을 묶은 책 즐겨찾기 추가', {exact:true}).click();
        await expect(page.getByLabel('약속을 묶은 책 즐겨찾기 해제', {exact:true})).toBeVisible();
        await shot(page, `${width}-wedding-saved`);
        await page.getByRole('button', {name:/^약속을 묶은 책 시안 열기/}).click();
        await expect(page.getByRole('button', {name:/^표지 미리보기/})).toBeVisible();
        await page.getByRole('button', {name:'유료 시안 목록',exact:true}).click();
        await expect(page.getByRole('checkbox', {name:'웨딩',exact:true})).toBeChecked();
        for (const study of studies) {
          await open(page, study.collectionId);
          await expect(page.getByRole('button', {name:/^표지 미리보기/})).toBeVisible();
          await choose(page, '판본 선택', fullVow ? '20쪽 이전 확장본' : '승인 8쪽 기준본');
          await expect.poll(() => page.locator('body').ariaSnapshot()).toContain(fullVow ? '20쪽 확장 · 추가 검토 · 미등록' : '디자인 승인 · 미등록');
          await choose(page, '앨범 규격', ratio);
          await shot(page, `${width}-${study.collectionId}-cover`);
          for (const [i, chapter] of study.chapters.entries()) {
            await choose(page, '목차', `${i * 2 + 1}–${i * 2 + 2} / ${chapter.title}`);
            await expect(page.getByRole('button', {name:new RegExp(`^${i*2+1}쪽 미리보기`)})).toBeVisible();
            await shot(page, `${width}-${study.collectionId}-spread-${i+1}`);
            if (width < 600) {
              await page.getByRole('button', {name:'다음 페이지',exact:true}).click();
              await expect(page.getByRole('button', {name:new RegExp(`^${i*2+2}쪽 미리보기`)})).toBeVisible();
              await shot(page, `${width}-${study.collectionId}-page-${i*2+2}`);
            }
          }
          await choose(page, '목차', '표지');
          await page.getByRole('button', {name:'문구 편집',exact:true}).click();
          await page.getByRole('textbox', {name:/^표지 제목/}).click();
          await page.waitForTimeout(150);
          await page.locator('input:focus,textarea:focus').fill('함께 남긴 기록');
          await page.waitForTimeout(150);
          await page.getByRole('button', {name:'문구 적용',exact:true}).click();
          await expect(page.getByRole('button', {name:/^표지 미리보기.*함께 남긴 기록/})).toBeVisible();
          await shot(page, `${width}-${study.collectionId}-edited`);
          if (fullVow) {
            await page.getByRole('button', {name:/^샘플 사진 숨기기(?: 샘플 사진 숨기기)?$/}).click();
            await expect(page.getByRole('button', {name:/^샘플 사진 보이기(?: 샘플 사진 보이기)?$/})).toBeVisible();
            await shot(page, `${width}-empty-photo-slot`);
            await page.getByRole('button', {name:/^샘플 사진 보이기(?: 샘플 사진 보이기)?$/}).click();
            await choose(page, '판본 선택', '승인 8쪽 기준본');
            await expect(page.getByRole('button', {name:/^표지 미리보기.*함께 남긴 기록/})).toBeVisible();
            await choose(page, '목차', '7–8 / 오래 간직할 것');
            await shot(page, `${width}-approved-ending`);
            await choose(page, '판본 선택', '20쪽 이전 확장본');
            await expect(page.getByRole('button', {name:/^표지 미리보기.*함께 남긴 기록/})).toBeVisible();
            await choose(page, '목차', '19–20 / 오래 간직할 것');
            await shot(page, `${width}-expanded-ending`);
            await choose(page, '목차', '표지');
          }
          checks.push({width,height,ratio,id:study.editionId || study.collectionId,pages:study.pages.length+1,spreads:study.chapters.length,copyEdit:true,editionSwitch:fullVow});
          console.log(`${width}: ${study.collectionId} passed`);
        }
        if (width === 1440) {
          await page.getByRole('button', {name:'꾸밈 재료',exact:true}).click();
          const materialName = fullVow ? '올리브 압인 봉인' : '산책 가방 이름표';
          const tag = page.getByLabel(`${materialName} 즐겨찾기 추가`, {exact:true});
          await revealMaterial(page, tag, 1);
          await expect(tag).toBeVisible();
          await shot(page, `${width}-new-materials`);
          await tag.click();
          await page.mouse.move(1,1);
          await page.waitForTimeout(350);
          const enlarged = page.getByRole('button', {name:new RegExp(`${materialName} 확대`)});
          await revealMaterial(page, enlarged, -1);
          await enlarged.click();
          await expect(page.getByRole('heading', {name:materialName,exact:true})).toBeVisible();
          await shot(page, `${width}-tag-enlarged`);
          await page.getByRole('button', {name:/^Back(?: Back)?$/}).click();
          await expect(page.getByRole('heading', {name:'꾸밈 재료',exact:true})).toBeVisible();
          await page.mouse.move(1,1);
          await page.waitForTimeout(350);
          await page.getByRole('button', {name:/^Back(?: Back)?$/}).click();
          await expect(page.getByRole('button', {name:/^표지 미리보기.*함께 남긴 기록/})).toBeVisible();
        }
        await page.getByRole('button', {name:'유료 시안 목록',exact:true}).click();
        await expect(page.getByRole('heading', {name:'유료 템플릿 시안',exact:true})).toBeVisible();
        await expect(page.getByLabel('약속을 묶은 책 즐겨찾기 해제', {exact:true})).toBeVisible();
        await shot(page, `${width}-saved-persisted`);
        assert.deepEqual(errors, []); assert.deepEqual(failures, []); assert.deepEqual(api, []);
        fs.writeFileSync(path.join(out,`${width}-report.json`), JSON.stringify({
          checks:checks.filter(c => c.width === width), apiRequests:0, hubFavoritesPersisted:true,
        },null,2));
        await context.close();
      } catch (e) {
        await page.screenshot({path:path.join(out,`${width}-failure.png`)});
        fs.writeFileSync(path.join(out,`${width}-failure.txt`), await page.locator('body').ariaSnapshot());
        throw e;
      }
    }
    const reportName = process.env.REVIEW_WIDTH ? `${process.env.REVIEW_WIDTH}-report.json` : 'report.json';
    fs.writeFileSync(path.join(out,reportName), JSON.stringify({checks,apiRequests:0,hubFavoritesPersisted:true},null,2));
  } finally {await browser.close();}
})().catch(e => {console.error(e); process.exitCode=1;});
