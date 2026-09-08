const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/favorites');
fs.mkdirSync(out, {recursive: true});

async function enable(page) {
  await page.waitForSelector('flt-semantics-placeholder', {state:'attached'});
  await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
  await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('즐겨찾기');
}

async function reach(page, control) {
  const v = page.viewportSize();
  for (let i=0; i<24; i++) {
    const b = await control.first().boundingBox().catch(() => null);
    if (b && b.y >= 0 && b.y+b.height <= v.height && b.x >= 0 && b.x+b.width <= v.width) return;
    await page.mouse.move(v.width-16, v.height*.7);
    await page.mouse.wheel(0, b ? Math.max(-150, Math.min(150, b.y-v.height*.55)) : 150);
    await page.waitForTimeout(120);
  }
  throw new Error('Favorite control is unreachable');
}

function star(page, label, remove=false) {
  return page.getByLabel(`${label} 즐겨찾기 ${remove ? '해제' : '추가'}`, {exact:true});
}

async function saved(page) {
  return page.evaluate(() => {
    const raw = localStorage.getItem('flutter.catalog_favorites_v1');
    if (!raw) return [];
    const decoded = JSON.parse(raw);
    return (typeof decoded === 'string' ? JSON.parse(decoded) : decoded).keys;
  });
}

async function screenshot(page, name) {
  await page.mouse.move(2, 2);
  await page.waitForTimeout(500);
  await page.screenshot({path:path.join(out,name)});
}

(async () => {
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const checks=[];
  try {
    for (const viewport of [{width:390,height:844},{width:844,height:390},{width:1440,height:900}]) {
      const context = await browser.newContext({viewport});
      const page = await context.newPage();
      page.setDefaultTimeout(15000);
      const errors=[], failed=[], api=[];
      page.on('pageerror', e=>errors.push(e.message));
      page.on('response', r=>{if(r.status()>=400)failed.push(r.url());});
      page.on('request', r=>{if(/api\.openai\.com|api\.anthropic\.com|\.supabase\.co/.test(r.url()))api.push(r.url());});
      await page.goto(`${root}/?studio=atelier&revision=favorites1#/atelier`);
      await enable(page);
      const artwork = page.getByRole('img', {name:/조합 미리보기/});
      await expect(artwork).toBeVisible();
      await page.waitForTimeout(400);
      const before = await artwork.screenshot();
      await reach(page, star(page,'사진 코너'));
      const target = await star(page,'사진 코너').boundingBox();
      assert(target.width>=44 && target.height>=44);
      await star(page,'사진 코너').click();
      await expect(star(page,'사진 코너',true)).toBeVisible();
      await expect.poll(()=>saved(page)).toEqual(['frame:studioPhotoCorners']);
      await reach(page, star(page,'이중 매트'));
      await star(page,'이중 매트').click();
      await expect.poll(()=>saved(page)).toEqual(['frame:studioDoubleMat','frame:studioPhotoCorners']);
      assert.equal(Buffer.compare(before,await artwork.screenshot()),0,'Favoriting must not change the album artwork');
      await page.getByRole('checkbox',{name:/즐겨찾기/}).click();
      await expect(page.getByLabel(/즐겨찾기 해제$/)).toHaveCount(2);
      const order=await page.getByLabel(/즐겨찾기 해제$/).evaluateAll(nodes=>nodes.map(n=>n.getAttribute('aria-label')));
      assert.deepEqual(order,['이중 매트 즐겨찾기 해제','사진 코너 즐겨찾기 해제']);
      checks.push({viewport,check:'independent target, save recency, filter'});
      await screenshot(page,`${viewport.width}-frames.png`);
      await page.reload(); await enable(page);
      await expect(star(page,'이중 매트',true)).toBeVisible();
      checks.push({viewport,check:'reload persistence'});
      await page.getByRole('tab',{name:'소재',exact:true}).click();
      await reach(page,star(page,'로즈 실크 리본'));
      await star(page,'로즈 실크 리본').click();
      await expect(star(page,'로즈 실크 리본',true)).toBeVisible();
      await page.getByRole('checkbox',{name:/즐겨찾기/}).click();
      await expect(page.getByLabel(/즐겨찾기 해제$/)).toHaveCount(1);
      await screenshot(page,`${viewport.width}-materials.png`);
      await star(page,'로즈 실크 리본',true).click();
      await expect(page.getByText('즐겨찾기한 항목이 없어요',{exact:true})).toBeVisible();
      await page.getByRole('button',{name:'전체 보기',exact:true}).click();
      await expect(star(page,'로즈 실크 리본')).toBeVisible();
      checks.push({viewport,check:'material save, unstar last item, empty recovery'});
      await page.getByRole('tab',{name:'문구',exact:true}).click();
      await reach(page,star(page,'우리가 서로의 집이 된 날'));
      await star(page,'우리가 서로의 집이 된 날').click();
      await page.getByRole('checkbox',{name:/즐겨찾기/}).click();
      await expect(page.getByLabel(/즐겨찾기 해제$/)).toHaveCount(1);
      await screenshot(page,`${viewport.width}-phrases.png`);
      checks.push({viewport,check:'editable phrase favorites'});
      // Navigate to a different picker that shares the same frame identity.
      await page.goto(`${root}/?frames=true&revision=favorites1#/frames`); await enable(page);
      await expect(star(page,'이중 매트',true)).toBeVisible();
      await expect(star(page,'사진 코너',true)).toBeVisible();
      checks.push({viewport,check:'cross-screen frame identity'});
      await page.goto(`${root}/?catalog=store&revision=favorites1#/store`); await enable(page);
      await reach(page,star(page,'빛으로 엮은 우리').first());
      await star(page,'빛으로 엮은 우리').first().click();
      await expect.poll(()=>saved(page)).toContain('template:lightbound');
      await page.getByRole('checkbox',{name:/즐겨찾기/}).click();
      await expect(page.getByRole('button',{name:/무료 룩북 보기/})).toHaveCount(1);
      await screenshot(page,`${viewport.width}-store.png`);
      checks.push({viewport,check:'store favorite filter and unchanged published catalog'});
      assert.deepEqual(errors,[]); assert.deepEqual(failed,[]); assert.deepEqual(api,[]);
      console.log(`${viewport.width}: favorites passed`);
      await context.close();
    }
    fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({checks},null,2));
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
