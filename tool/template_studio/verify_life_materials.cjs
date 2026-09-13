const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/materials/life-variety/browser');
const materials = [
  '첫 놀이 나무 딸랑이', '민트 거즈 턱받이', '일요일 버드나무 바구니',
  '숲색 법랑 컵', '나란한 코튼 실내화', '창가의 올리브 화병',
  '작은 양모 장난감', '청록 테두리 세라믹 식기', '봉제선 성장 라벨',
  '절취선 피크닉 카드', '접어 둔 생활 메모', '색인형 관찰 카드',
];
fs.mkdirSync(out, {recursive:true});
// Flutter's lazy grid scrolls in the canvas, not in the semantics DOM.
async function reveal(page, target, picker = false) {
  const {width,height} = page.viewportSize();
  const minY = picker && width < height ? height * .55 : 160;
  await page.mouse.move(width * .8, height * .8);
  await page.mouse.wheel(0,-10000);
  await page.waitForTimeout(150);
  for (let i=0; i<24; i++) {
    const b = await target.boundingBox({timeout:100}).catch(()=>null);
    if (b && b.y>=minY && b.y+b.height<=height-6) return;
    await page.mouse.wheel(0,180);
    await page.waitForTimeout(100);
  }
  throw new Error(`Could not reveal ${target}`);
}
const paperSwatches = [
  [[228,237,240],[195,211,219]],
  [[246,245,233],[117,134,105]],
  [[236,232,239],[213,205,217]],
  [[231,238,234],[123,153,144]],
];
async function shot(page, name, paperIndex = -1) {
  await page.mouse.move(1,1);
  await page.waitForTimeout(500);
  const p = PNG.sync.read(await page.screenshot({path:path.join(out, `${name}.png`)}));
  const colors = new Set();
  for (let i=0; i<p.data.length; i+=64) colors.add(`${p.data[i]>>3},${p.data[i+1]>>3},${p.data[i+2]>>3}`);
  if (paperIndex < 0) {
    assert(colors.size>70, `${name}: missing artwork`);
  } else {
    // Restrained stationery needs paper + construction detail, not photo-like color variety.
    for (const swatch of paperSwatches[paperIndex]) {
      let matches = 0;
      for (let y=Math.ceil(p.height*.2); y<p.height*.85; y++) {
        for (let x=Math.ceil(p.width*.05); x<p.width*.95; x++) {
          const i=(y*p.width+x)*4;
          if (swatch.every((v,c)=>Math.abs(p.data[i+c]-v)<5)) matches++;
        }
      }
      assert(matches>50, `${name}: missing paper or construction detail ${swatch}`);
    }
  }
}
(async()=>{
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const reports=[];
  try {
    for (const [width,height] of [[390,844],[844,390],[1440,900]]) {
      const context=await browser.newContext({viewport:{width,height}});
      const page=await context.newPage();
      page.setDefaultTimeout(30000);
      const errors=[],failures=[];
      page.on('pageerror',e=>errors.push(e.message));
      page.on('response',r=>{if(r.status()>=400) failures.push(r.url());});
      await page.goto(`${root}/?materials=keepsake&revision=material-variety-12#/keepsake-materials`);
      await page.waitForSelector('flt-semantics-placeholder',{state:'attached',timeout:60000});
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('재료 라이브러리 83');
      await page.getByRole('tab',{name:/스티커·종이/}).click();
      for (const [i,name] of materials.entries()) {
        const favorite = page.getByRole('switch',{name:new RegExp(`^${name} 즐겨찾기 추가`)});
        await reveal(page,favorite);
        await favorite.click();
        await reveal(page,page.getByRole('button',{name:new RegExp(`^${name} 확대`)}));
        await page.getByRole('button',{name:new RegExp(`^${name} 확대`)}).click();
        await shot(page,`${width}-material-${i+1}`,i<8 ? -1 : i-8);
        await page.getByRole('button',{name:/Back|뒤로/}).first().click();
        await expect(page.getByRole('switch',{name:new RegExp(`^${name} 즐겨찾기 해제`)})).toBeVisible();
      }
      await page.getByRole('button',{name:/^재료 편집 미리보기/}).click();
      for (const [i,name] of materials.entries()) {
        const insert = page.getByRole('button',{name:new RegExp(`^${name} 추가`)});
        await reveal(page,insert,true);
        await insert.click();
        await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain(`${name} 크게 보기`);
        await shot(page,`${width}-insert-${i+1}`);
      }
      assert.deepEqual(errors,[]); assert.deepEqual(failures,[]);
      reports.push({width,height,materials:materials.length,favorites:true,insertions:materials.length,errors,failures});
      fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(reports,null,2));
      console.log(`${width}: ${materials.length} life materials passed`);
      await context.close();
    }
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
