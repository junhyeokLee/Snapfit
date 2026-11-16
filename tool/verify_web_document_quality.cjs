#!/usr/bin/env node
// Isolated browser proof for tool/web_document_quality_fixture.dart.
// No user browser profile, real account, API request or photo upload is used.
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const args = Object.fromEntries(process.argv.slice(2).map(argument => {
  const i = argument.indexOf('=');
  if (!argument.startsWith('--') || i < 3) throw new Error('Use --name=value arguments');
  return [argument.slice(2, i), argument.slice(i + 1)];
}));
const build = fs.realpathSync(path.resolve(args.build || 'build/document-quality-web'));
const output = path.resolve(args.output || 'output/web-document-quality/report.json');
const artifactsDirectory = path.dirname(output);
const fullManifest = fs.readFileSync(path.join(build, 'assets/FontManifest.json'));
const types = {'.html': 'text/html; charset=utf-8', '.js': 'application/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.ttf': 'font/ttf',
  '.otf': 'font/otf', '.woff2': 'font/woff2', '.png': 'image/png', '.jpg': 'image/jpeg'};
function fileFor(relative) {
  const file = fs.realpathSync(path.resolve(build, relative));
  assert.ok(file.startsWith(build + path.sep), 'Path escapes fixture build');
  assert.ok(fs.statSync(file).isFile());
  return file;
}
const server = http.createServer((request, response) => {
  let relative;
  try { relative = decodeURIComponent(new URL(request.url, 'http://localhost').pathname).slice(1); }
  catch (_) { response.writeHead(400).end(); return; }
  let file;
  try { file = fileFor(relative || 'index.html'); }
  catch (_) { response.writeHead(404).end(); return; }
  response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
  response.setHeader('Cache-Control', 'no-store');
  fs.createReadStream(file).on('error', () => response.destroy()).pipe(response);
});
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

(async () => {
  fs.mkdirSync(artifactsDirectory, {recursive: true});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = 'http://127.0.0.1:' + server.address().port + '/';
  const browser = await chromium.launch({headless: true,
    executablePath: args.chrome || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
  const modes = {};
  try {
    for (const mode of ['eager', 'deferred']) {
      const context = await browser.newContext({viewport: {width: 1280, height: 1000},
        serviceWorkers: 'block', colorScheme: 'light'});
      const page = await context.newPage();
      const pageErrors = [];
      const forbiddenExternalRequests = [];
      const isolatedPluginStubs = [];
      const localCanvasKitResponses = [];
      const requests = [];
      page.on('pageerror', error => pageErrors.push(error.message));
      page.on('request', request => requests.push({url: request.url(), method: request.method()}));
      // Use the exact local CanvasKit bytes even if the SDK's normal loader
      // chooses the versioned public CDN URL. All other external requests fail.
      await context.route('**/*', async route => {
        const url = new URL(route.request().url());
        if (url.origin === new URL(base).origin) {
          if (mode === 'eager' && /\/assets\/StartupFontManifest\.[a-f0-9]+\.json$/.test(url.pathname)) {
            await route.fulfill({status: 200, contentType: 'application/json',
              headers: {'Cache-Control': 'no-store'}, body: fullManifest});
          } else await route.continue();
          return;
        }
        // The generated Flutter plugin registry prepares Google Sign-In even
        // in this account-free fixture. Supply an inert local script; no login
        // is initiated and no request is allowed to leave the fixture server.
        if (url.href === 'https://accounts.google.com/gsi/client' &&
            route.request().method() === 'GET') {
          isolatedPluginStubs.push(url.href);
          await route.fulfill({status: 200, contentType: 'application/javascript',
            body: '/* Isolated document fixture: sign-in is not used. */'});
          return;
        }
        if (url.hostname === 'www.gstatic.com' && url.pathname.startsWith('/flutter-canvaskit/')) {
          const match = url.pathname.match(/\/([^/]+\/)?(canvaskit\.(?:js|wasm))$/);
          if (match) {
            const variant = match[1] === 'chromium/' ? 'chromium/' : '';
            const relative = 'canvaskit/' + variant + match[2];
            try {
              const file = fileFor(relative);
              localCanvasKitResponses.push({requestedURL: url.href, localFile: relative});
              await route.fulfill({status: 200, contentType: types[path.extname(file)],
                headers: {'Access-Control-Allow-Origin': '*'}, body: fs.readFileSync(file)});
              return;
            } catch (_) { /* Fail the check rather than contact the CDN. */ }
          }
        }
        forbiddenExternalRequests.push(url.href);
        await route.abort('blockedbyclient');
      });
      try {
        await page.goto(base + '?mode=' + mode, {waitUntil: 'domcontentloaded', timeout: 120000});
        await page.waitForFunction(() => globalThis.__snapfitDocumentQuality?.done === true,
          null, {timeout: 180000});
        const result = await page.evaluate(() => globalThis.__snapfitDocumentQuality);
        const folder = path.join(artifactsDirectory, mode);
        fs.mkdirSync(folder, {recursive: true});
        const artifactFiles = [];
        for (const [name, encoded] of Object.entries(result.artifacts || {})) {
          assert.match(name, /^[a-z0-9-]+\.(?:png|pdf)$/);
          const bytes = Buffer.from(encoded, 'base64');
          if (name.endsWith('.pdf')) assert.match(bytes.subarray(0, 8).toString('ascii'), /^%PDF-1\./);
          else assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
          const file = path.join(folder, name);
          fs.writeFileSync(file, bytes);
          artifactFiles.push({path: file, bytes: bytes.length, sha256: hash(bytes)});
        }
        delete result.artifacts;
        await page.waitForTimeout(350);
        const screenshot = path.join(folder, 'actual-browser-screen.png');
        await page.screenshot({path: screenshot, fullPage: true});
        modes[mode] = {...result, pageErrors, forbiddenExternalRequests, isolatedPluginStubs,
          localCanvasKitResponses, requests, artifactFiles, screenshot};
        fs.writeFileSync(path.join(folder, 'result.json'), JSON.stringify(modes[mode], null, 2) + '\n');
      } finally { await context.close(); }
    }
    const checks = [];
    const equal = (name, a, b) => checks.push({name, equal: JSON.stringify(a) === JSON.stringify(b), eager: a, deferred: b});
    const eager = modes.eager.proof;
    const deferred = modes.deferred.proof;
    if (eager && deferred) {
      equal('frozen saved JSON', eager.snapshotShaBefore, deferred.snapshotShaBefore);
      equal('saved layer geometry', eager.geometryShaAfter, deferred.geometryShaAfter);
      for (const name of ['layerBeforeAll', 'layerAfterAll', 'templateBeforeAll', 'templateAfterAll']) {
        equal(name + ' RGBA pixels', eager[name]?.pixelSha, deferred[name]?.pixelSha);
        equal(name + ' dimensions', [eager[name]?.width, eager[name]?.height],
          [deferred[name]?.width, deferred[name]?.height]);
      }
      equal('original photo bytes and decoded dimensions', eager.originalPhoto, deferred.originalPhoto);
      equal('cover PDF bytes', eager.print?.coverPdfSha, deferred.print?.coverPdfSha);
      equal('interior PDF bytes', eager.print?.interiorPdfSha, deferred.print?.interiorPdfSha);
      equal('published snapshot RGBA', eager.publication?.pixelSha, deferred.publication?.pixelSha);
      equal('published snapshot dimensions', [eager.publication?.width, eager.publication?.height],
        [deferred.publication?.width, deferred.publication?.height]);
      equal('print resolution and geometry report', eager.print?.report, deferred.print?.report);
    }
    const startupPolicyVerified = eager?.coverFontsReadyBeforeGate === true &&
      deferred?.coverFontsReadyBeforeGate === false &&
      deferred?.printOnlyFontReadyBeforeExport === false &&
      deferred?.print?.printOnlyFontReadyAfterExport === true &&
      deferred?.publicationOnlyFontReadyBeforePrepare === false &&
      deferred?.publication?.fontReadyAfterPrepare === true;
    const passed = startupPolicyVerified && checks.length > 0 && checks.every(check => check.equal) &&
      Object.values(modes).every(mode => mode.passed && mode.pageErrors.length === 0 &&
        mode.forbiddenExternalRequests.length === 0);
    const report = {passed, build, startupPolicyVerified,
      scenario: 'Same isolated Flutter release fixture: complete engine font manifest vs UI-only engine manifest and real deferred app loaders',
      limitations: ['Small local 20mm/300dpi/two-page print stock exercises real PDFs; it does not validate any production vendor specification.',
        'The unused generated Google Sign-In plugin script is answered with an inert local fixture stub; authentication is not tested.',
        'Customer album storage, authentication, billing, uploads and database access are not involved.',
        'Saved layer renderers and the all-font editing precondition are exercised; the full interactive editor route and persistence are not mounted.',
        'This is functional/visual quality verification, not a speed benchmark.'], checks, modes};
    fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify({passed, output, startupPolicyVerified,
      equalComparisons: checks.filter(check => check.equal).length,
      failedComparisons: checks.filter(check => !check.equal),
      modes: Object.fromEntries(Object.entries(modes).map(([name, value]) => [name,
        {passed: value.passed, errors: value.errors, pageErrors: value.pageErrors,
          forbiddenExternalRequests: value.forbiddenExternalRequests}])),
    }, null, 2));
    assert.equal(passed, true, 'Actual saved artwork, PDF or publication changed with deferred fonts');
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => {
  console.error(error);
  server.close();
  process.exitCode = 1;
});
