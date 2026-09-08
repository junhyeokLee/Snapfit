const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {expect} = require('playwright/test');
const {PNG} = require('pngjs');
const root = process.env.TEMPLATE_PREVIEW_URL || 'http://127.0.0.1:4323';
const out = path.resolve('output/template-preview/published-store');
const titles = ['빛으로 엮은 우리', '여행의 결', '작은 날의 기록',
  '우리의 서약', '정원에서의 약속', '영화 같던 하루', '사랑의 편지',
  '바다를 건너', '도시의 수집가', '느리게 걷는 길', '여행의 우편함',
  '계절의 식탁', '취향 보관함', '함께라서 좋은 날', '주말의 온도',
  '너의 첫해', '작은 걸음의 기록', '너라는 봄', '알록달록 자라는 날', '처음 맞는 생일', '우리 집의 사계절', '한 식탁의 이야기', '우리의 좋은 사이', '세대를 잇는 사진', '함께 떠난 소풍', '너와 나의 날짜들', '둘만의 장면', '사랑이 머문 계절', '오래도록 우리', '둘이 모은 조각', '너의 하루를 따라', '낮잠의 모양', '산책이라는 약속', '우리 집 작은 가족', '가장 다정한 얼굴'];
fs.mkdirSync(out, {recursive: true});
titles.push('바람을 수집한 여행');
const queryTitles = process.env.STORE_TITLE ? titles.filter(title => title === process.env.STORE_TITLE) : titles;

function colorCount(bytes) {
  const png = PNG.sync.read(bytes), colors = new Set();
  for (let i = 0; i < png.data.length; i += 16) {
    colors.add(`${png.data[i] >> 3},${png.data[i+1] >> 3},${png.data[i+2] >> 3}`);
  }
  return colors.size;
}

async function reach(page, locator) {
  const {width, height} = page.viewportSize();
  for (let i = 0; i < 25; i++) {
    const box = await locator.first().boundingBox().catch(() => null);
    if (box && box.y >= 0 && box.y + Math.min(box.height, height - 16) <= height - 8) return;
    await page.mouse.move(width - 12, height / 2);
    const target = box ? Math.max(8, (height - box.height) / 2) : 0;
    await page.mouse.wheel(0, box ? Math.max(-220, Math.min(220, box.y - target)) : 220);
    await page.waitForTimeout(100);
  }
  throw new Error('Could not scroll to control');
}

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const results = [];
  try {
    for (const viewport of [{width:390,height:844}, {width:844,height:390}, {width:1440,height:900}]) {
      const page = await browser.newPage({viewport});
      page.setDefaultTimeout(15000);
      const errors = [], failures = [], api = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => { if (r.status() >= 400) failures.push(r.url()); });
      page.on('request', r => { if (/\.supabase\.co|api\.openai\.com|api\.anthropic\.com/.test(r.url())) api.push(r.url()); });
      await page.goto(`${root}/?catalog=store`);
      await page.waitForSelector('flt-semantics-placeholder', {state: 'attached'});
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('무료 36종');
      await expect.poll(async () => colorCount(await page.screenshot())).toBeGreaterThan(250);
      await page.screenshot({path: path.join(out, `${viewport.width}-store.png`)});
      const search = page.getByRole('textbox');
      let previous = '';
      for (const title of [...queryTitles, '제주의 기록']) {
        await page.bringToFront();
        console.log(`${viewport.width}: searching ${title}`);
        await reach(page, search);
        await search.click();
        const input = page.locator('input');
        await input.waitFor();
        await expect(input).toBeFocused();
        await page.evaluate(() => Promise.race([
          new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))),
          new Promise(resolve => setTimeout(resolve, 150)),
        ]));
        // Flutter restores the controller's value after HTML focus is acquired.
        await expect(input).toHaveValue(previous);
        await input.fill(title);
        await expect(input).toHaveValue(title);
        await expect.poll(() => page.locator('body').ariaSnapshot()).toContain(
          `고른 ${titles.includes(title) ? 1 : 0}개의`,
        );
        const cards = page.getByRole('button', {name: /무료 룩북 보기/});
        if (titles.includes(title)) {
          await reach(page, cards);
          await expect(cards).toHaveCount(1);
          await expect(cards).toHaveAccessibleName(new RegExp(title));
          await page.screenshot({path: path.join(out, `${viewport.width}-${title}.png`)});
          if (title === '바람을 수집한 여행') {
            const star = page.getByRole('switch', {name: `${title} 즐겨찾기 추가`, exact:true});
            await reach(page, star);
            await star.click();
            const selectedStar = page.getByRole('switch', {name: `${title} 즐겨찾기 해제`, exact:true}).first();
            await reach(page, selectedStar);
            await expect(selectedStar).toBeVisible();
            await expect(cards).toHaveCount(1);
            await expect.poll(() => page.evaluate(() => localStorage.getItem('flutter.catalog_favorites_v1'))).toContain('template:wind-atlas');
            results.push({viewport, action:'wind-atlas free store favorite without opening or applying'});
          }
        } else {
          await expect(cards).toHaveCount(0);
        }
        previous = title;
        results.push({viewport, query:title, count:titles.includes(title) ? 1 : 0});
      }
      await reach(page, search);
      await search.click();
      await expect(page.locator('input')).toHaveValue(previous);
      await page.locator('input').fill('');
      await expect.poll(() => page.locator('body').ariaSnapshot()).toContain('고른 36개의');
      for (const topic of ['웨딩', '여행', '일상', '성장·육아', '가족·친구', '커플·기념일', '반려동물']) {
        const filter = page.getByRole('button', {name:topic, exact:true});
        await reach(page, filter);
        const box = await filter.boundingBox();
        assert(box.x >= 0 && box.x + box.width <= viewport.width);
        assert(box.height >= 44);
        await filter.click();
        await expect.poll(() => page.locator('body').ariaSnapshot()).toContain(`${topic} 분위기에 어울리는 ${topic === '여행' ? 6 : 5}개`);
        await page.screenshot({path: path.join(out, `${viewport.width}-topic-${topic}.png`)});
        results.push({viewport, topic, count:topic === '여행' ? 6 : 5});
      }
      assert.deepEqual(errors, []);
      assert.deepEqual(failures, []);
      assert.deepEqual(api, []);
      console.log(`${viewport.width}: thirty-six free collections, actual covers, search and retired exclusion passed`);
      await page.close();
    }
    fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify({results}, null, 2));
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
