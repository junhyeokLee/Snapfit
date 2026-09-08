const { chromium } = require('playwright');
const { PNG } = require('pngjs');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const root = path.resolve(__dirname, '../..');
const out = path.join(root, 'output/template-studio');

async function main() {
  // The HTML is an offline review artifact. Vendor the installed icon library.
  await fs.copyFile(require.resolve('lucide/dist/umd/lucide.min.js'), path.join(out, 'lucide.js'));
  await fs.copyFile(path.join(__dirname, 'index.html'), path.join(out, 'index.html'));
  await fs.mkdir(path.join(out, 'qa'), { recursive: true });
  const browser = await chromium.launch({ headless: true, channel: process.env.PLAYWRIGHT_CHANNEL || 'chrome' });
  const failures = [];
  let checks = 0;
  try {
    for (const [width, height] of [[1440,1000],[390,844],[320,568],[844,390]]) {
      const page = await browser.newPage({ viewport: { width, height }, reducedMotion: 'reduce' });
      page.on('pageerror', error => failures.push(error.message));
      page.on('console', msg => { if (msg.type() === 'error') failures.push(msg.text()); });
      await page.goto(pathToFileURL(path.join(out, 'index.html')).href);
      await page.evaluate(() => document.fonts.ready);
      async function loaded() {
        await page.waitForFunction(() => [...document.images].every(i => i.complete && i.naturalWidth > 0));
        assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), `Horizontal overflow ${width}x${height}`);
        checks++;
      }
      await loaded();
      assert.equal(await page.locator('.study-cover img').count(), 3);
      assert(await page.locator('svg.lucide').count() > 0);
      await page.screenshot({ path: path.join(out, `qa/overview-${width}x${height}.png`), fullPage: true });
      for (const aspect of ['portrait','square','landscape']) {
        await page.locator(`[data-aspect="${aspect}"]`).click();
        await loaded();
        await page.locator('.study-cover[data-open="island"]').click();
        for (const direction of ['island','dear','offduty']) {
          await page.locator(`[data-direction="${direction}"]`).click();
          for (let p = 0; p < 3; p++) {
            await page.locator(`.thumb[data-page="${p}"]`).click();
            await loaded();
            const book = await page.locator('#book').boundingBox();
            const stage = await page.locator('#stage').boundingBox();
            assert(book.width > 100 && book.height > 50, 'Nonblank book dimensions');
            assert(book.x >= stage.x && book.x + book.width <= stage.x + stage.width + 1);
            assert(book.y >= stage.y && book.y + book.height <= stage.y + stage.height + 1);
            assert.equal(await page.locator('#book img').count(), p === 0 ? 1 : 2);
            const a = await page.evaluate(() => STUDIO.aspects.find(a=>a.id===state.aspect));
            assert(Math.abs(book.width/book.height - (a.width/a.height)*(p===0?1:2)) < .01, 'Physical aspect preserved');
            if (width === 1440 && p === 1) {
              await page.screenshot({ path:path.join(out,`qa/${direction}-${aspect}.png`),fullPage:true });
            }
          }
        }
        await page.locator('#overviewButton').click();
      }
      await page.locator('.study-cover[data-open="dear"]').click();
      await page.locator('#photos').uncheck();
      await loaded();
      assert((await page.locator('#book img').first().getAttribute('src')).includes('_empty_'));
      await page.locator('#photos').check();
      await page.locator('#next').click();
      assert.equal(await page.locator('#pageLabel').textContent(), '1–2쪽');
      await page.screenshot({path:path.join(out,`qa/reader-${width}x${height}.png`),fullPage:true});
      await page.locator('#zoom').click();
      await loaded();
      assert(await page.locator('#zoomDialog').isVisible());
      await page.locator('#zoomNext').click();
      assert.equal(await page.locator('#zoomLabel').textContent(), width<=700?'2쪽':'3–4쪽');
      await page.locator('#zoomSingle').click();
      assert.equal(await page.locator('#zoomBook img').count(), 1);
      await page.screenshot({path:path.join(out,`qa/zoom-${width}x${height}.png`)});
      await page.locator('#zoomSpread').click();
      assert.equal(await page.locator('#zoomBook img').count(), 2);
      await page.keyboard.press('Escape');
      assert(!await page.locator('#zoomDialog').isVisible());
      await page.locator('#favorite').click();
      assert.equal(await page.locator('#favorite').getAttribute('aria-pressed'), 'true');
      await page.reload();
      await loaded();
      assert(await page.evaluate(() => JSON.parse(localStorage.getItem('snapfit-studio-favorite')).direction === 'dear'));
      await page.close();
    }

    // Every filled render must differ materially from its empty-slot counterpart.
    for (const direction of ['island','dear','offduty']) {
      for (const aspect of ['portrait','square','landscape']) {
        for (let p=0;p<5;p++) {
          const filename = `${direction}_${aspect}`;
          const photo = PNG.sync.read(await fs.readFile(path.join(out, `renders/${filename}_photo_${p}.png`)));
          const empty = PNG.sync.read(await fs.readFile(path.join(out, `renders/${filename}_empty_${p}.png`)));
          let changed = 0;
          for(let i=0;i<photo.data.length;i+=4) {
            if(Math.abs(photo.data[i]-empty.data[i])+Math.abs(photo.data[i+1]-empty.data[i+1])+Math.abs(photo.data[i+2]-empty.data[i+2])>40) changed++;
          }
          assert(changed/(photo.width*photo.height)>.025, `${filename}/${p} missing photo pixels`);
          checks++;
        }
      }
    }
    assert.deepEqual(failures, []);
    await fs.writeFile(path.join(out,'qa/report.json'),JSON.stringify({checks, viewports:[[1440,1000],[390,844],[320,568],[844,390]], errors:failures, generatedAt:new Date().toISOString()},null,2));
    process.stdout.write(`Template Studio: ${checks} layout/image checks passed; 4 viewports, 9 documents, 45 photo pages.\n`);
  } finally {
    await browser.close();
  }
}
main().catch(error=>{process.stderr.write(error.stack+'\n');process.exitCode=1;});
