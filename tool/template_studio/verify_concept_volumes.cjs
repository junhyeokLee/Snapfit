const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/concept-wave/browser');
fs.mkdirSync(out, {recursive:true});
const allBooks = ['first-wardrobe','sunday-picnic','shared-seasons','little-companion','silk-vows','shore-days','reading-room'];
const books = process.env.CONCEPT_BOOKS ? process.env.CONCEPT_BOOKS.split(',') : allBooks;
assert(books.length && books.every(id => allBooks.includes(id)), 'Unknown concept volume');
const revision = process.env.CONCEPT_REVISION || 'shared-paper-3';
async function choose(page, tooltip, name) {
  await page.getByRole('button', {name:new RegExp(`^${tooltip}(?: ${tooltip})?$`)}).click();
  const target = page.getByRole('menuitem', {name,exact:true});
  for (let i=0; i<24; i++) {
    const b = await target.boundingBox({timeout:200}).catch(() => null);
    const menu = await page.getByRole('menu').boundingBox();
    const top = Math.max(0,menu.y), bottom = Math.min(page.viewportSize().height,menu.y+menu.height);
    if (b && b.y>=top && b.y+b.height<=bottom) break;
    await page.mouse.move(menu.x+menu.width/2,top+(bottom-top)*.7);
    await page.mouse.wheel(0,b && b.y<top ? -230 : 230);
    await page.waitForTimeout(90);
  }
  await target.click();
}
async function shot(page, name) {
  await page.mouse.move(1,1);
  await page.waitForTimeout(500);
  const png = PNG.sync.read(await page.screenshot({path:path.join(out,`${name}.png`)}));
  const colors = new Set();
  for (let i=0; i<png.data.length; i+=32) colors.add(`${png.data[i]>>3},${png.data[i+1]>>3},${png.data[i+2]>>3}`);
  assert(colors.size>100, `${name}: blank artwork`);
}
(async () => {
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const reports = [];
  try {
    for (const [width,height,ratio] of [[390,844,'세로형'],[844,390,'가로형'],[1440,900,'정사각형']]) {
      const context = await browser.newContext({viewport:{width,height}});
      const page = await context.newPage();
      page.setDefaultTimeout(30000);
      const errors=[], failed=[], api=[];
      page.on('pageerror', e=>errors.push(e.message));
      page.on('response', r=>{if(r.status()>=400) failed.push(r.url());});
      page.on('request', r=>{if(/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url());});
      try {
        for (const id of books) {
          const doc = JSON.parse(fs.readFileSync(`output/template-preview/concept-wave/${id}/square/document.json`, 'utf8'));
          await page.goto(`${root}/?collection=${id}&revision=${revision}#/${id}`);
          await page.waitForSelector('flt-semantics-placeholder',{state:'attached',timeout:60000});
          await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
          await expect(page.getByRole('button',{name:/^표지 미리보기/})).toBeVisible({timeout:60000});
          await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('내지 24쪽');
          await choose(page,'앨범 규격',ratio);
          await shot(page,`${width}-${id}-cover`);
          for (const i of [0,5,11]) {
            const chapter = doc.chapters[i];
            await choose(page,'목차',`${chapter.from}–${chapter.to} / ${chapter.title}`);
            await expect(page.getByRole('button',{name:new RegExp(`^${chapter.from}쪽 미리보기`)})).toBeVisible();
            await shot(page,`${width}-${id}-spread-${i+1}`);
            if (width<600) {
              await page.getByRole('button',{name:'다음 페이지',exact:true}).click();
              await expect(page.getByRole('button',{name:new RegExp(`^${chapter.to}쪽 미리보기`)})).toBeVisible();
            }
          }
          await choose(page,'목차','표지');
          await page.getByRole('button',{name:'문구 편집',exact:true}).click();
          await page.getByRole('textbox',{name:/^표지 제목/}).click();
          await page.waitForTimeout(150);
          await page.locator('input:focus,textarea:focus').fill('우리의 기록');
          await page.waitForTimeout(150);
          await page.getByRole('button',{name:'문구 적용',exact:true}).click();
          await expect(page.getByRole('button',{name:/^표지 미리보기.*우리의 기록/})).toBeVisible();
          await page.getByRole('button',{name:/^샘플 사진 숨기기(?: 샘플 사진 숨기기)?$/}).click();
          await page.mouse.move(1,1);
          await expect(page.getByRole('button',{name:/^샘플 사진 보이기(?: 샘플 사진 보이기)?$/})).toBeVisible();
          await page.getByRole('button',{name:/^샘플 사진 보이기(?: 샘플 사진 보이기)?$/}).click();
          await page.mouse.move(1,1);
          await page.getByRole('switch',{name:`${doc.title} 즐겨찾기 추가`,exact:true}).click();
          await expect(page.getByRole('switch',{name:`${doc.title} 즐겨찾기 해제`,exact:true})).toBeVisible();
          await page.getByRole('button',{name:'유료 시안 목록',exact:true}).click();
          await expect(page.getByRole('heading',{name:'유료 템플릿 시안',exact:true})).toBeVisible();
          await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('14종');
          await shot(page,`${width}-${id}-catalog`);
          reports.push({id,width,height,ratio,innerPages:24,chaptersChecked:[1,6,12],editableTitle:true,photoSlots:true,favorite:true});
          assert.deepEqual(errors,[]); assert.deepEqual(failed,[]); assert.deepEqual(api,[]);
          fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({revision,books,checks:reports,apiRequests:0},null,2));
          console.log(`${width}: ${id} passed`);
        }
      } catch (e) {
        await page.screenshot({path:path.join(out,`${width}-failure.png`)});
        fs.writeFileSync(path.join(out,`${width}-failure.txt`),await page.locator('body').ariaSnapshot());
        throw e;
      } finally {await context.close();}
    }
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
