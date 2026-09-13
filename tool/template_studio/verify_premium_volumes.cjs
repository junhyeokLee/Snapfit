const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const books = [
  ['vow-keepsake',32], ['luminous-edition',36], ['daily-cabinet',24],
  ['first-year-keepsake',36], ['table-stories',32], ['two-tickets',32], ['walk-and-nap',24],
];
const out = path.resolve('output/template-preview/premium-volumes/browser');
fs.mkdirSync(out, {recursive:true});
const document = (id,count) => JSON.parse(fs.readFileSync(`output/template-preview/${id}-${count}/square/document.json`, 'utf8'));
const label = count => `${count}쪽 ${count === 24 ? '기본판' : '확장판'}`;
const chapterLabel = c => `${c.from}–${c.to} / ${c.title}`;
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
  await page.mouse.move(1,1);
}
async function shot(page,name) {
  await page.mouse.move(1,1);
  await page.waitForTimeout(650);
  const png = PNG.sync.read(await page.screenshot({path:path.join(out,`${name}.png`)}));
  const colors = new Set();
  for (let i=0;i<png.data.length;i+=32) colors.add(`${png.data[i]>>3},${png.data[i+1]>>3},${png.data[i+2]>>3}`);
  assert(colors.size>100,`${name}: blank canvas`);
}
async function goChapter(page,c) {
  await choose(page,'목차',chapterLabel(c));
  await expect(page.getByRole('button',{name:new RegExp(`^${c.from}쪽 미리보기`)})).toBeVisible();
}
(async () => {
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const reports = [];
  try {
    for (const [width,height,ratio] of [[390,844,'세로형'],[844,390,'가로형'],[1440,900,'정사각형']]) {
      if (process.env.REVIEW_WIDTH && width!==Number(process.env.REVIEW_WIDTH)) continue;
      const context = await browser.newContext({viewport:{width,height}});
      const page = await context.newPage();
      page.setDefaultTimeout(30000);
      const errors=[],failed=[],api=[];
      page.on('pageerror',e=>errors.push(e.message));
      page.on('response',r=>{if(r.status()>=400) failed.push(r.url());});
      page.on('request',r=>{if(/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url());});
      try {
        for (const [id,max] of books) {
          if (process.env.REVIEW_BOOK && id!==process.env.REVIEW_BOOK) continue;
          const full=document(id,max), basic=document(id,24);
          await page.goto(`${root}/?collection=${id}&revision=volumes2436#/${id}`);
          await page.waitForSelector('flt-semantics-placeholder',{state:'attached',timeout:60000});
          await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
          await expect(page.getByRole('button',{name:/^표지 미리보기/})).toBeVisible({timeout:60000});
          await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain(`내지 ${max}쪽`);
          await choose(page,'앨범 규격',ratio);
          await shot(page,`${width}-${id}-cover`);
          const indices = process.env.ALL_SPREADS
            ? full.chapters.map((_,i)=>i)
            : [1,Math.floor(full.chapters.length/2),full.chapters.length-1];
          for (const i of indices) {
            await goChapter(page,full.chapters[i]);
            await shot(page,`${width}-${id}-spread-${i+1}`);
            if (width<600) {
              await page.getByRole('button',{name:'다음 페이지',exact:true}).click();
              await expect(page.getByRole('button',{name:new RegExp(`^${full.chapters[i].to}쪽 미리보기`)})).toBeVisible();
              await shot(page,`${width}-${id}-page-${full.chapters[i].to}`);
            }
          }
          await choose(page,'목차','표지');
          await page.getByRole('button',{name:'문구 편집',exact:true}).click();
          const travel=id==='luminous-edition';
          const editedTitle = travel ? '함께한' : '함께한 기록';
          const editedCover = new RegExp(`^표지 미리보기.*${editedTitle}`);
          await page.getByRole('textbox',{name:travel ? /^윗줄/ : /^표지 제목/}).click();
          await page.waitForTimeout(120);
          await page.locator('input:focus,textarea:focus').fill(editedTitle);
          await page.waitForTimeout(150);
          await page.getByRole('button',{name:'문구 적용',exact:true}).click();
          await expect(page.getByRole('button',{name:editedCover})).toBeVisible();
          await choose(page,'판본 선택',label(24));
          await expect(page.getByRole('button',{name:editedCover})).toBeVisible();
          await goChapter(page,basic.chapters.at(-1));
          await shot(page,`${width}-${id}-basic-ending`);
          await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('내지 24쪽');
          await choose(page,'판본 선택','승인 8쪽 기준본');
          await expect(page.getByRole('button',{name:editedCover})).toBeVisible();
          await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('내지 8쪽');
          await choose(page,'판본 선택',label(max));
          await expect(page.getByRole('button',{name:editedCover})).toBeVisible();
          await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain(`내지 ${max}쪽`);
          await goChapter(page,full.chapters.at(-1));
          await shot(page,`${width}-${id}-restored-ending`);
          await page.getByRole('button',{name:'유료 시안 목록',exact:true}).click();
          await expect(page.getByRole('heading',{name:'유료 템플릿 시안',exact:true})).toBeVisible();
          await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('내지 24~36쪽');
          if (id===books[0][0] || process.env.REVIEW_BOOK) await shot(page,`${width}-premium-catalog`);
          reports.push({width,height,ratio,id,basic:24,extended:max,reviewedSpreads:indices.length,copyPreserved:true,endingPreserved:true});
          assert.deepEqual(errors,[]); assert.deepEqual(failed,[]); assert.deepEqual(api,[]);
          fs.writeFileSync(path.join(out,`${width}${process.env.REVIEW_BOOK ? '-'+id : ''}-report.json`),JSON.stringify({checks:reports.filter(r=>r.width===width),apiRequests:0},null,2));
          console.log(`${width}: ${id} 24/${max} passed`);
        }
      } catch(e) {
        await page.screenshot({path:path.join(out,`${width}-failure.png`)});
        fs.writeFileSync(path.join(out,`${width}-failure.txt`),await page.locator('body').ariaSnapshot());
        throw e;
      } finally {await context.close();}
    }
    if (!process.env.REVIEW_WIDTH && !process.env.REVIEW_BOOK) fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({checks:reports,apiRequests:0},null,2));
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
