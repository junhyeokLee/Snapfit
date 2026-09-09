const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/materials/atelier-36/browser');
fs.mkdirSync(out, {recursive:true});

async function shot(page, name) {
  await page.mouse.move(1,1);
  await page.waitForTimeout(650);
  const p = PNG.sync.read(await page.screenshot({path:path.join(out, `${name}.png`)}));
  const colors = new Set();
  for (let i=0; i<p.data.length; i+=4*17) colors.add(`${p.data[i]>>3}:${p.data[i+1]>>3}:${p.data[i+2]>>3}`);
  assert(colors.size>24, `${name} has no rendered artwork`);
}

(async () => {
  const browser = await chromium.launch({channel:'chrome', headless:true});
  const reports = [];
  try {
    for (const [width,height] of [[390,844],[844,390],[1440,900]]) {
      const context = await browser.newContext({viewport:{width,height}});
      const page = await context.newPage();
      page.setDefaultTimeout(30000);
      const errors=[], failed=[], api=[];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => {if(r.status()>=400) failed.push(r.url());});
      page.on('request', r => {if(/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url());});
      await page.goto(`${root}/?materials=keepsake&revision=atelier64#/keepsake-materials`);
      await page.waitForSelector('flt-semantics-placeholder', {state:'attached',timeout:60000});
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('재료 라이브러리 64');
      await shot(page, `${width}-all`);
      await page.getByRole('tab',{name:/스티커·종이/}).click();
      await page.getByRole('checkbox', {name:/^서약의 아틀리에$/}).click();
      await expect(page.getByRole('button',{name:/^자수 레이스 코너 확대/})).toBeVisible();
      await page.getByRole('switch',{name:/^자수 레이스 코너 즐겨찾기 추가/}).click();
      await expect(page.getByRole('switch',{name:/^자수 레이스 코너 즐겨찾기 해제/})).toBeVisible();
      await page.getByRole('button',{name:/^자수 레이스 코너 확대/}).click();
      await shot(page,`${width}-lace`);
      await page.getByRole('button',{name:/Back|뒤로/}).first().click();
      await page.getByRole('tab',{name:/프레임/}).click();
      await expect(page.getByRole('button',{name:/^세 겹 단차 액자 확대/})).toBeVisible();
      await shot(page,`${width}-frames`);
      await page.getByRole('button',{name:/^세 겹 단차 액자 확대/}).click();
      await shot(page,`${width}-photo-frame`);
      await page.getByRole('button',{name:/Back|뒤로/}).first().click();
      await page.getByRole('tab',{name:/^문구$/}).click();
      await expect(page.getByRole('button',{name:/^압인 청첩장 타이틀 확대/})).toBeVisible();
      await page.getByRole('switch',{name:/^압인 청첩장 타이틀 즐겨찾기 추가/}).click();
      await shot(page,`${width}-lettering`);
      await page.getByRole('button',{name:/^압인 청첩장 타이틀 확대/}).click();
      await shot(page,`${width}-wordart`);
      await page.getByRole('button',{name:/Back|뒤로/}).first().click();
      await page.getByRole('button',{name:/^재료 편집 미리보기/}).click();
      await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('종이와 스티커');
      await page.getByRole('button',{name:/^해변에서 주운 조개 추가/}).click();
      await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('해변에서 주운 조개 크게 보기');
      await shot(page,`${width}-editor-insert`);
      await page.getByRole('tab',{name:/^꾸민 문구$/}).click();
      await page.getByRole('button',{name:/^압인 청첩장 타이틀 추가/}).click();
      await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('압인 청첩장 타이틀 크게 보기');
      await shot(page,`${width}-editor-wordart`);
      assert.deepEqual(errors,[], 'browser errors');
      assert.deepEqual(failed,[], 'missing assets');
      assert.deepEqual(api,[], 'local workbench must not call purchases or generation APIs');
      reports.push({width,height,passed:true,screenshots:8,errors,failed,api});
      await context.close();
    }
    fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(reports,null,2));
    console.log(JSON.stringify(reports,null,2));
  } finally {
    await browser.close();
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
