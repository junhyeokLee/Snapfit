import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';

const require = createRequire(import.meta.url);
const {chromium} = require('playwright');
const {PNG} = require('pngjs');
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const out = path.join(repo, 'output/brand-studio');
const url = process.env.BRAND_URL || 'http://127.0.0.1:4323/brand/';
await fs.mkdir(out, {recursive:true});
const results = [];
const colorSource = await fs.readFile(path.join(repo, 'lib/core/constants/snapfit_colors.dart'), 'utf8');
const tokenNames = {'--brand-accent':'accent','--brand-accent-light':'accentLight','--brand-ink':'deepCharcoal','--brand-white':'pureWhite'};
const expectedTokens = Object.fromEntries(Object.entries(tokenNames).map(([cssName, dartName]) => {
  const declaration = colorSource.split('\n').find(line => line.includes('static const Color ' + dartName + ' ='));
  const match = declaration?.match(/Color\(0xFF([0-9A-Fa-f]{6})\)/);
  assert(match, 'Missing source color ' + dartName);
  return [cssName, '#' + match[1].toLowerCase()];
}));
const assets = ['wordmark-cyan.png','app-icon-cyan.png','splash-portrait.png','splash-landscape.png'];
for (const name of assets) {
  const png = PNG.sync.read(await fs.readFile(path.join(repo, 'assets/brand/album-mark', name)));
  let opaque = 0;
  const colors = new Set();
  for (let i = 0; i < png.data.length; i += 4) {
    if (png.data[i+3] === 255) opaque++;
    if (i % 256 === 0) colors.add(png.data.subarray(i,i+3).join(','));
  }
  assert(colors.size > 50, name + ' unexpectedly blank');
  assert(opaque === png.width * png.height, name + ' must be opaque');
  results.push({asset:name,width:png.width,height:png.height,opaque:true,colors:colors.size});
}
const browser = await chromium.launch({channel:'chrome',headless:true});
try {
  for (const [width,height] of [[320,568],[390,844],[844,390],[1440,900]]) {
    const page = await browser.newPage({viewport:{width,height},deviceScaleFactor:1});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('response', response => {if (response.status() >= 400) errors.push(response.status() + ' ' + response.url());});
    await page.goto(url);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForFunction(() => [...document.images].every(img => img.complete && img.naturalWidth > 0));
    const actualTokens = await page.evaluate(names => Object.fromEntries(names.map(name => [name, getComputedStyle(document.documentElement).getPropertyValue(name).trim()])), Object.keys(tokenNames));
    assert.deepEqual(actualTokens, expectedTokens, 'Preview must use actual Flutter brand colors');
    const swatches = await page.locator('.palette code').allTextContents();
    assert.deepEqual(swatches.map(color => color.toLowerCase()), Object.values(expectedTokens));
    const expected = height > width ? 'portrait' : 'landscape';
    assert((await page.locator('#splashImage').getAttribute('src')).includes(expected));
    for (const orientation of ['portrait','landscape']) {
      await page.locator('[data-orientation=' + orientation + ']').click();
      await page.locator('#splashImage').evaluate(img => img.decode());
      assert.equal(await page.locator('[data-orientation=' + orientation + ']').getAttribute('aria-pressed'),'true');
      assert((await page.locator('#splashDownload').getAttribute('href')).includes(orientation));
      const box = await page.locator('#splashImage').boundingBox();
      assert(box.width > 200 && box.height > 100);
      assert(box.y + box.height <= height + 1, 'splash outside viewport');
      await page.screenshot({path:path.join(out,width + 'x' + height + '-' + orientation + '.png')});
    }
    for (const tab of ['identity','sources','splash']) {
      await page.locator('#tab-' + tab).click();
      assert(await page.locator('#' + tab).isVisible());
      assert.equal(await page.locator('[role=tabpanel]:visible').count(),1);
      const overflow = await page.evaluate(() => {
        const viewport = document.documentElement.clientWidth;
        return [...document.querySelectorAll('body *')].filter(el => {
          const box = el.getBoundingClientRect();
          return box.width > 0 && box.height > 0 && (box.left < -1 || box.right > viewport + 1);
        }).map(el => el.id || el.className || el.tagName);
      });
      assert.deepEqual(overflow,[], 'horizontal overflow: ' + width + '/' + tab);
      if (tab !== 'splash') await page.screenshot({path:path.join(out,width + 'x' + height + '-' + tab + '.png'),fullPage:true});
    }
    await page.locator('#tab-splash').focus();
    await page.keyboard.press('ArrowRight');
    assert(await page.locator('#identity').isVisible());
    await page.keyboard.press('End');
    assert(await page.locator('#sources').isVisible());
    await page.keyboard.press('Home');
    assert(await page.locator('#splash').isVisible());
    const [download] = await Promise.all([
      page.waitForEvent('download'), page.locator('#splashDownload').click()
    ]);
    assert.equal(download.suggestedFilename(),'snapfit-splash-landscape.png');
    assert.equal(await download.failure(),null);
    assert.deepEqual(errors,[]);
    results.push({viewport:width + 'x' + height,orientations:2,tabs:3,keyboard:true,download:true,brandTokens:actualTokens,errors});
    await page.close();
  }
} finally {await browser.close();}
await fs.writeFile(path.join(out, 'verification.json'), JSON.stringify(results,null,2));
console.log(JSON.stringify(results,null,2));
