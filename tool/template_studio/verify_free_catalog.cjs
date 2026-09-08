const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/free-expansion/browser');
const titles = ['빛으로 엮은 우리', '여행의 결', '작은 날의 기록',
  '우리의 서약', '정원에서의 약속', '영화 같던 하루', '사랑의 편지',
  '바다를 건너', '도시의 수집가', '느리게 걷는 길', '여행의 우편함',
  '계절의 식탁', '취향 보관함', '함께라서 좋은 날', '주말의 온도',
  '너의 첫해', '작은 걸음의 기록', '너라는 봄', '알록달록 자라는 날', '처음 맞는 생일', '우리 집의 사계절', '한 식탁의 이야기', '우리의 좋은 사이', '세대를 잇는 사진', '함께 떠난 소풍', '너와 나의 날짜들', '둘만의 장면', '사랑이 머문 계절', '오래도록 우리', '둘이 모은 조각', '너의 하루를 따라', '낮잠의 모양', '산책이라는 약속', '우리 집 작은 가족', '가장 다정한 얼굴'];
const viewports = [{width:390,height:844},{width:844,height:390},{width:1440,height:900}];
const selectedTitles = process.env.TEMPLATE_PREVIEW_TITLES
  ? process.env.TEMPLATE_PREVIEW_TITLES.split('|') : titles;
assert(selectedTitles.every(title => titles.includes(title)));
fs.mkdirSync(out, {recursive:true});

function colors(bytes, box) {
  const p = PNG.sync.read(bytes), set = new Set();
  for (let y=Math.ceil(box.y); y<Math.min(p.height,box.y+box.height); y+=2) {
    for (let x=Math.ceil(box.x); x<Math.min(p.width,box.x+box.width); x+=2) {
      const i=(y*p.width+x)*4;
      set.add(`${p.data[i]>>3},${p.data[i+1]>>3},${p.data[i+2]>>3}`);
    }
  }
  return set.size;
}

(async()=>{
  const browser=await chromium.launch({channel:'chrome',headless:true});
  const results=[];
  try {
    for(const viewport of viewports){
      const page=await browser.newPage({viewport});
      const errors=[], failed=[], api=[];
      page.on('pageerror',e=>errors.push(e.message));
      page.on('response',r=>{if(r.status()>=400)failed.push(r.url());});
      page.on('request',r=>{if(/api\.openai\.com|api\.anthropic\.com|\.supabase\.co/.test(r.url()))api.push(r.url());});
      await page.goto(root);
      await page.waitForSelector('flt-semantics-placeholder',{state:'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      const button=name=>page.getByRole('button',{name:typeof name==='string'?new RegExp(name):name});
      for(const title of selectedTitles){
        await button('시안 선택').click();
        await expect(page.getByRole('menuitem')).toHaveCount(41);
        for (const label of [...titles, '사진 프레임', '종이·스티커']) {
          await expect(page.getByRole('menuitem', {name:label, exact:true})).toBeVisible();
        }
        await page.getByRole('menuitem',{name:title,exact:true}).click();
        await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('무료 · 표지 + 내지 24쪽');
        for(const [format,ratio] of [['세로형',14.5/19.4],['정사각형',1],['가로형',19.4/14.5]]){
          await button('앨범 규격').click();
          await page.getByRole('menuitem',{name:format,exact:true}).click();
          await button('목차').click();
          await page.getByRole('menuitem',{name:'표지',exact:true}).click();
          const cover=button(/^표지 미리보기/);
          await cover.waitFor();
          let box,bytes,count;
          await expect.poll(async()=>{
            box=await cover.boundingBox(); bytes=await page.screenshot();
            return count=colors(bytes,box);
          },{timeout:10000}).toBeGreaterThan(180);
          assert(Math.abs(box.width/box.height-ratio)<.025);
          assert(box.x>=0 && box.y>=0 && box.x+box.width<=viewport.width+1 && box.y+box.height<=viewport.height+1);
          const stem=`${viewport.width}-${title}-${format}`;
          fs.writeFileSync(path.join(out,`${stem}.png`),bytes);
          await button('목차').click();
          await page.getByRole('menuitem',{name:/^23–24/}).click();
          await button(/^23쪽 미리보기/).waitFor();
          await button('문구 편집').click();
          await button('문구 편집 닫기').click();
          results.push({title,format,viewport,box,colors:count});
          console.log(`${stem}: free label, curated menu, cover, contents and copy form passed`);
        }
      }
      await button('시안 선택').click();
      await page.getByRole('menuitem',{name:'사진 프레임',exact:true}).click();
      await page.screenshot({path:path.join(out,`${viewport.width}-frame-tool.png`)});
      assert.deepEqual(errors,[]);assert.deepEqual(failed,[]);assert.deepEqual(api,[]);
      await page.close();
    }
    fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({source:'Free catalog, archived selections removed',selectedTitles,results},null,2));
    console.log(`${results.length} free collection/format/viewport combinations passed.`);
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
