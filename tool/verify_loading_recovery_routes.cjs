#!/usr/bin/env node
// Fresh guest context only: no customer cookies, login, purchase or album writes.
const { chromium } = require('playwright');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const path = require('node:path');
const output = path.resolve(process.argv[2] || 'output/loading-recovery-20261101/public-web');

(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ headless: true,
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 },
    serviceWorkers: 'block' });
  const page = await context.newPage();
  const errors = [], unexpectedWrites = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => {
    const url = new URL(request.url());
    if (url.hostname.endsWith('.supabase.co') && request.method() !== 'GET' &&
        /purchase|create_album|save_moment|claim_daily|redeem_referral/.test(url.pathname)) {
      unexpectedWrites.push({ method: request.method(), path: url.pathname });
    }
  });
  await page.addInitScript(() => {
    window.__snapfitLoaded = false;
    window.addEventListener('flutter-first-frame', () => window.__snapfitLoaded = true);
  });
  const report = { url: 'https://snapfit-c719d.web.app/feed', guest: true };
  try {
    await page.goto(report.url, { waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.waitForFunction(() => window.__snapfitLoaded, null, { timeout: 90000 });
    const semantics = page.getByRole('button', { name: 'Enable accessibility', exact: true });
    // Flutter's screen-reader activation control is intentionally offscreen.
    if (await semantics.count()) await semantics.dispatchEvent('click');
    await page.getByRole('button', { name: '템플릿·소재', exact: true }).click();
    await page.getByText(/디자인 둘러보기|모든 템플릿|지금 둘러보기 좋은 디자인/)
      .first().waitFor({ timeout: 30000 });
    report.storeVisible = true;
    await page.screenshot({ path: path.join(output, 'store.png') });
    report.storeButtons = await page.getByRole('button').evaluateAll(nodes => nodes
      .map(node => node.getAttribute('aria-label') || node.textContent || '').filter(Boolean));
    const detail = page.getByRole('button', { name: /상세 보기/ }).first();
    if (await detail.count()) {
      await detail.click();
    } else {
      // Guest InkWell cards expose their labels as non-button semantics. At
      // this fixed viewport the captured first cover occupies x160–425,
      // y329–580; click that visible cover after its compare control mounts.
      await page.getByRole('button', { name: '비교', exact: true }).first().waitFor();
      await page.mouse.click(292, 460);
    }
    report.detailButtons = await page.getByRole('button').evaluateAll(nodes => nodes
      .map(node => node.getAttribute('aria-label') || node.textContent || '').filter(Boolean));
    const start = page.getByRole('button', { name: '로그인하고 이 디자인으로 시작', exact: true }).first();
    await start.waitFor({ timeout: 30000 });
    await start.click();
    report.guestDesignStartReachedLogin = true;
    await page.getByRole('button', { name: '이메일로 로그인', exact: true }).waitFor({ timeout: 30000 });
    report.privateGuestAccessReachedLogin = true;
    report.finalURL = page.url();
    await page.screenshot({ path: path.join(output, 'login.png') });
    assert.equal(errors.length, 0, 'Unexpected browser error');
    assert.equal(unexpectedWrites.length, 0, 'Guest test must never create/purchase/publish');
    report.passed = true;
  } catch (error) {
    report.passed = false;
    report.error = error.message;
    await page.screenshot({ path: path.join(output, 'failure.png') }).catch(() => {});
    throw error;
  } finally {
    Object.assign(report, { errors, unexpectedWrites });
    fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify(report, null, 2) + '\n');
    await browser.close();
    console.log(JSON.stringify({ passed: report.passed, storeVisible: report.storeVisible,
      guestDesignStartReachedLogin: report.guestDesignStartReachedLogin,
      privateGuestAccessReachedLogin: report.privateGuestAccessReachedLogin, errors }));
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
