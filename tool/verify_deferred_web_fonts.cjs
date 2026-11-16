#!/usr/bin/env node
// Read-only quality check of eager and deferred registration in shipped CanvasKit.
// Usage: node tool/verify_deferred_web_fonts.cjs --build=build/review-web \
//   --startup-manifest=assets/StartupFontManifest.<hash>.json --output=output/proof.json
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const options = Object.fromEntries(process.argv.slice(2).map(argument => {
  const split = argument.indexOf('=');
  if (!argument.startsWith('--') || split < 3) {
    throw new Error('Arguments must use --name=value');
  }
  return [argument.slice(2, split), argument.slice(split + 1)];
}));
const build = fs.realpathSync(path.resolve(options.build || 'build/review-web'));
const output = path.resolve(options.output || 'output/deferred-web-font-rendering.json');
const manifestName = options.manifest || 'assets/FontManifest.json';
const startupCandidates = fs.readdirSync(path.join(build, 'assets'))
  .filter(name => /^StartupFontManifest\.[a-f0-9]{20,64}\.json$/.test(name));
const startupName = options['startup-manifest'] || (startupCandidates.length === 1
  ? 'assets/' + startupCandidates[0] : null);
assert.ok(startupName, 'Specify --startup-manifest when there is not one unambiguous startup manifest');

function buildFile(relative) {
  const file = fs.realpathSync(path.resolve(build, relative));
  assert.ok(file.startsWith(build + path.sep), 'Path escapes the selected build: ' + relative);
  assert.ok(fs.statSync(file).isFile(), 'Not a file: ' + relative);
  return file;
}
function manifest(relative) {
  const value = JSON.parse(fs.readFileSync(buildFile(relative), 'utf8'));
  assert.ok(Array.isArray(value), 'Expected a font manifest list');
  for (const family of value) {
    assert.equal(typeof family.family, 'string');
    assert.ok(Array.isArray(family.fonts) && family.fonts.length > 0);
    for (const font of family.fonts) {
      assert.equal(typeof font.asset, 'string');
      assert.ok(!font.asset.startsWith('/') && !font.asset.includes('..') &&
        !font.asset.includes('\\') && !font.asset.includes(':'), 'Unsafe font asset');
      buildFile('assets/' + font.asset);
    }
  }
  return value;
}
const complete = manifest(manifestName);
const startup = manifest(startupName);
const completeFamilies = new Map(complete.map(family => [family.family, family]));
assert.equal(completeFamilies.size, complete.length, 'Duplicate full-manifest family');
assert.equal(new Set(startup.map(family => family.family)).size, startup.length,
  'Duplicate startup-manifest family');
for (const family of startup) {
  assert.deepEqual(family, completeFamilies.get(family.family),
    'Startup family descriptors must be preserved exactly: ' + family.family);
}
const documentFamilies = complete.filter(family => family.fonts.some(font =>
  /^(?:assets\/fonts\/|web_fonts\/)/.test(font.asset)));
assert.ok(documentFamilies.length > 0, 'No document families were found');
buildFile('canvaskit/canvaskit.js');

const server = http.createServer((request, response) => {
  let relative;
  try { relative = decodeURIComponent(new URL(request.url, 'http://localhost').pathname).slice(1); }
  catch (_) { response.writeHead(400).end(); return; }
  if (relative === 'favicon.ico') { response.writeHead(204).end(); return; }
  if (!relative) {
    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    response.end('<!doctype html><title>Deferred SnapFit font quality verification</title>');
    return;
  }
  let file;
  try { file = buildFile(relative); }
  catch (_) { response.writeHead(404).end(); return; }
  const types = {'.js': 'application/javascript', '.wasm': 'application/wasm',
    '.json': 'application/json', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2'};
  response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
  fs.createReadStream(file).on('error', () => response.destroy()).pipe(response);
});

(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = 'http://127.0.0.1:' + server.address().port + '/';
  const browser = await chromium.launch({headless: true,
    executablePath: options.chrome || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
  const pageErrors = [];
  const consoleErrors = [];
  try {
    const page = await browser.newPage();
    page.on('pageerror', error => pageErrors.push(error.message));
    page.on('console', message => {
      if (message.type() === 'error') consoleErrors.push(message.text());
    });
    await page.goto(base);
    const result = await page.evaluate(async ({base, complete, startup, documentFamilies}) => {
      const {default: initialize} = await import(base + 'canvaskit/canvaskit.js');
      const kit = await initialize({locateFile: file => base + 'canvaskit/' + file});
      const digest = async value => Array.from(new Uint8Array(
        await crypto.subtle.digest('SHA-256', value))).map(byte =>
          byte.toString(16).padStart(2, '0')).join('');
      const bytes = new Map();
      for (const family of complete) {
        for (const font of family.fonts) {
          if (bytes.has(font.asset)) continue;
          const response = await fetch(new URL('assets/' + font.asset, base));
          if (!response.ok) throw new Error(font.asset + ': HTTP ' + response.status);
          const buffer = new Uint8Array(await response.arrayBuffer());
          const face = kit.Typeface.MakeFreeTypeFaceFromData(buffer);
          if (!face) throw new Error('Invalid font: ' + font.asset);
          face.delete();
          bytes.set(font.asset, buffer);
        }
      }
      const startupNames = new Set(startup.map(family => family.family));
      const dynamicFamilies = complete.filter(family => !startupNames.has(family.family));
      function provider(families) {
        const manager = kit.TypefaceFontProvider.Make();
        for (const family of families) {
          for (const font of family.fonts) manager.registerFont(bytes.get(font.asset), family.family);
        }
        const collection = kit.FontCollection.Make();
        collection.enableFontFallback();
        collection.setDefaultFontManager(manager);
        return {manager, collection, dispose() { collection.delete(); manager.delete(); }};
      }
      // The final deferred registration order is the UI subset, followed by
      // complete family/face order for every subsequently loaded family.
      const eager = provider(complete);
      const deferred = provider([...startup, ...dynamicFamilies]);
      const text = '우리의 앨범 · 사진과 기록\nSnapFit AV fi ffi 012345\n가나다 한글 한 !?';
      const sizes = [12, 28, 54];
      const widths = [180, 420];
      const weights = [400, 600, 700, 800, 900];
      const fontWeights = {400: kit.FontWeight.Normal, 600: kit.FontWeight.SemiBold,
        700: kit.FontWeight.Bold, 800: kit.FontWeight.ExtraBold, 900: kit.FontWeight.Black};
      for (const weight of weights) {
        if (!fontWeights[weight]) throw new Error('Unsupported CanvasKit weight ' + weight);
      }
      async function render(registration, family, size, width, weight) {
        const builder = kit.ParagraphBuilder.MakeFromFontCollection(kit.ParagraphStyle({
          textStyle: {fontFamilies: [family, 'NotoSans', 'Roboto'], fontSize: size,
            fontStyle: {weight: fontWeights[weight], slant: kit.FontSlant.Upright}, color: kit.BLACK},
          textDirection: kit.TextDirection.LTR,
        }), registration.collection);
        builder.addText(text);
        const paragraph = builder.build();
        let surface;
        try {
          paragraph.layout(width);
          const height = Math.ceil(paragraph.getHeight()) + 20;
          if (height < 1 || height > 4096) throw new Error('Unexpected paragraph extent');
          surface = kit.MakeSurface(width + 20, height);
          if (!surface) throw new Error('No software surface');
          const canvas = surface.getCanvas();
          canvas.clear(kit.WHITE);
          canvas.drawParagraph(paragraph, 10, 10);
          surface.flush();
          const pixels = canvas.readPixels(0, 0, {width: width + 20, height,
            colorType: kit.ColorType.RGBA_8888, alphaType: kit.AlphaType.Unpremul,
            colorSpace: kit.ColorSpace.SRGB});
          if (!pixels) throw new Error('No paragraph pixels');
          const lineKeys = ['startIndex', 'endIndex', 'endExcludingWhitespaces',
            'endIncludingNewline', 'isHardBreak', 'ascent', 'descent', 'height', 'width',
            'left', 'baseline', 'lineNumber'];
          const metrics = {height: paragraph.getHeight(), longestLine: paragraph.getLongestLine(),
            minIntrinsicWidth: paragraph.getMinIntrinsicWidth(),
            maxIntrinsicWidth: paragraph.getMaxIntrinsicWidth(),
            alphabeticBaseline: paragraph.getAlphabeticBaseline(),
            ideographicBaseline: paragraph.getIdeographicBaseline(),
            lines: paragraph.getLineMetrics().map(line => Object.fromEntries(
              lineKeys.map(key => [key, line[key]]))),
            boxes: paragraph.getRectsForRange(0, text.length, kit.RectHeightStyle.Tight,
              kit.RectWidthStyle.Tight).map(box => ({rect: Array.from(box.rect),
                direction: box.dir?.value ?? box.dir}))};
          return {metricsSha: await digest(new TextEncoder().encode(JSON.stringify(metrics))),
            pixelSha: await digest(pixels), lineCount: metrics.lines.length,
            height: metrics.height, longestLine: metrics.longestLine};
        } finally {
          surface?.delete(); paragraph.delete(); builder.delete();
        }
      }
      const checks = [];
      try {
        for (const family of documentFamilies) {
          const cases = [];
          for (const size of sizes) for (const width of widths) for (const weight of weights) {
            const before = await render(eager, family.family, size, width, weight);
            const after = await render(deferred, family.family, size, width, weight);
            cases.push({size, width, weight, metricsEqual: before.metricsSha === after.metricsSha,
              pixelsEqual: before.pixelSha === after.pixelSha, eager: before, deferred: after});
          }
          checks.push({family: family.family, faces: family.fonts.map(font => ({...font})), cases,
            passed: cases.every(value => value.metricsEqual && value.pixelsEqual)});
        }
        // Direct glyph IDs, advances and bounds additionally detect any buffer
        // or face change caused by the different registration lifetime/order.
        const glyphChecks = [];
        for (const [asset, buffer] of bytes) {
          if (!documentFamilies.some(family => family.fonts.some(font => font.asset === asset))) continue;
          function glyphMeasurements(copy) {
            const face = kit.Typeface.MakeFreeTypeFaceFromData(copy);
            if (!face) throw new Error('No glyph face: ' + asset);
            try {
              return sizes.map(size => {
                const font = new kit.Font(face, size);
                try {
                  const ids = font.getGlyphIDs(text);
                  return {size, ids: Array.from(ids), advances: Array.from(font.getGlyphWidths(ids)),
                    bounds: Array.from(font.getGlyphBounds(ids))};
                } finally { font.delete(); }
              });
            } finally { face.delete(); }
          }
          const original = glyphMeasurements(buffer);
          const replay = glyphMeasurements(buffer.slice());
          const originalSha = await digest(new TextEncoder().encode(JSON.stringify(original)));
          const replaySha = await digest(new TextEncoder().encode(JSON.stringify(replay)));
          glyphChecks.push({asset, bytes: buffer.byteLength, byteSha: await digest(buffer),
            glyphsAdvancesBoundsEqual: originalSha === replaySha, originalSha, replaySha});
        }
        return {checks, glyphChecks, startupFamilies: startup.map(family => family.family),
          dynamicFamilies: dynamicFamilies.map(family => family.family), sizes, widths, weights, text};
      } finally { deferred.dispose(); eager.dispose(); }
    }, {base, complete, startup, documentFamilies});
    const passed = result.checks.every(check => check.passed) &&
      result.glyphChecks.every(check => check.glyphsAdvancesBoundsEqual) && pageErrors.length === 0;
    const report = {passed, build, fullManifest: manifestName, startupManifest: startupName,
      renderer: 'The selected Flutter build CanvasKit software rasterizer and TypefaceFontProvider/FontCollection',
      comparison: 'All full-manifest faces in manifest order vs startup subset first and deferred families in full-manifest order',
      limitations: ['This isolates typeface registration quality; it does not assert app navigation gates or network retry behavior.',
        'Explicit NotoSans/Roboto fallback is identical in both modes; no external fallback-font service is used.'],
      pageErrors, consoleErrors, ...result};
    fs.mkdirSync(path.dirname(output), {recursive: true});
    fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
    const failed = result.checks.flatMap(check => check.cases.filter(value =>
      !value.metricsEqual || !value.pixelsEqual).map(value => ({family: check.family,
        size: value.size, width: value.width, weight: value.weight})));
    console.log(JSON.stringify({passed, output, documentFamilies: result.checks.length,
      paragraphCases: result.checks.reduce((sum, check) => sum + check.cases.length, 0),
      glyphFiles: result.glyphChecks.length, pageErrors, consoleErrors, failed}, null, 2));
    assert.equal(passed, true, 'Deferred font registration changed rendered typography');
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => {
  console.error(error);
  server.close();
  process.exitCode = 1;
});
