import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SPEC = importlib.util.spec_from_file_location(
    'build_web', Path(__file__).resolve().parents[2] / 'tool/build_web.py',
)
BUILD_WEB = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD_WEB)
NODE = shutil.which('node')

STARTUP_HARNESS = r"""
const fs = require('node:fs');
const vm = require('node:vm');
const scenario = JSON.parse(fs.readFileSync(0, 'utf8'));
const requests = [];
const events = [];
const cache = new Map();
const storageChanges = [];
const deadlines = [];
const unregistered = [];
const messages = [];
let entrypointLoaded;
let releaseFont;
let releaseWorkers;
let releaseUnregister;
const fontGate = new Promise(resolve => {releaseFont = resolve;});
const workerGate = new Promise(resolve => {releaseWorkers = resolve;});
const unregisterGate = new Promise(resolve => {releaseUnregister = resolve;});
const manifest = [
  {family: 'MaterialIcons', fonts: [
    {asset: 'fonts/MaterialIcons-Regular.otf'},
    {asset: 'fonts/MaterialIcons-Regular.otf'},
    {asset: 'https://other.test/external.otf'},
    {asset: '../outside.otf'},
  ]},
  {family: 'packages/cupertino_icons/CupertinoIcons', fonts: [
    {asset: 'packages/cupertino_icons/assets/CupertinoIcons.ttf'},
  ]},
  {family: 'NotoSans', fonts: [{asset: 'assets/fonts/NotoSans-Regular.ttf'}]},
];
function registration(name, scriptURL, scope) {
  return {scope, active: {scriptURL}, async unregister() {
    events.push('unregister-start:' + name);
    if (scenario.unregisterTimeout) await new Promise(() => {});
    if (scenario.holdUnregister) await unregisterGate;
    if (scenario.unregisterError) throw new Error('unregister unavailable');
    unregistered.push(name);
    return !scenario.unregisterFailure;
  }};
}
const navigator = {};
if (scenario.workers || scenario.holdWorkers || scenario.workerTimeout ||
    scenario.workerFailure || scenario.holdUnregister || scenario.controlled ||
    scenario.alreadyRetired || scenario.controllerKind || scenario.unregisterTimeout) {
  navigator.serviceWorker = {
    controller: scenario.controlled || scenario.controllerKind ? {scriptURL:
      scenario.controllerKind === 'firebase'
        ? 'https://snapfit.test/app/firebase-messaging-sw.js'
        : scenario.controllerKind === 'other-origin'
        ? 'https://other.test/app/flutter_service_worker.js'
        : 'https://snapfit.test/app/flutter_service_worker.js'} : null,
    async getRegistrations() {
    events.push('worker-query');
    if (scenario.workerFailure) throw new Error('worker API unavailable');
    if (scenario.workerTimeout) await new Promise(() => {});
    if (scenario.holdWorkers) await workerGate;
    if (scenario.alreadyRetired) return [];
    return [
      registration('generated', 'https://snapfit.test/app/flutter_service_worker.js',
                   scenario.otherScope ? 'https://snapfit.test/app/other/'
                     : 'https://snapfit.test/app/'),
      registration('firebase', 'https://snapfit.test/app/firebase-messaging-sw.js',
                   'https://snapfit.test/app/'),
      registration('other-scope', 'https://snapfit.test/other/flutter_service_worker.js',
                   'https://snapfit.test/other/'),
      registration('other-origin', 'https://other.test/app/flutter_service_worker.js',
                   'https://snapfit.test/app/'),
    ];
  }};
}
const context = {
  URL, AbortController, navigator,
  document: {
    baseURI: 'https://snapfit.test/app/',
    createElement(tag) {return {tag, style: {}, children: [],
      append(...children) {this.children.push(...children);}};},
    body: {append(message) {messages.push(message);}},
  },
  location: {reload() {events.push('reload');}},
  localStorage: {clear: () => storageChanges.push('localStorage')},
  indexedDB: {deleteDatabase: () => storageChanges.push('indexedDB')},
  caches: {delete: () => storageChanges.push('caches')},
  setTimeout(callback, delay) {
    deadlines.push(delay);
    const expire = (scenario.expire && delay === 4000) ||
      ((scenario.workerTimeout || scenario.unregisterTimeout) && delay === 500);
    return setTimeout(callback, expire ? 0 : delay);
  },
  clearTimeout,
  async fetch(input, options) {
    const url = String(input);
    requests.push({url, cache: options.cache});
    if (scenario.expire) {
      return new Promise((_, reject) => {
        options.signal.addEventListener('abort', () => reject(new Error('aborted')));
      });
    }
    if (url.endsWith('FontManifest.json')) {
      if (scenario.manifestFailure === 'network') throw new Error('offline');
      return {
        ok: scenario.manifestFailure !== 'status',
        async json() {
          if (scenario.manifestFailure === 'json') throw new Error('invalid json');
          cache.set(url, 'current manifest');
          return scenario.manifestFailure === 'shape' ? {} : manifest;
        },
      };
    }
    if (scenario.holdFont) await fontGate;
    if (scenario.fontFailure === 'network' && url.includes('MaterialIcons')) {
      throw new Error('font offline');
    }
    return {
      ok: !(scenario.fontFailure === 'status' && url.includes('MaterialIcons')),
      async arrayBuffer() {
        if (scenario.fontFailure === 'body' && url.includes('MaterialIcons')) {
          throw new Error('incomplete body');
        }
        await new Promise(resolve => setImmediate(resolve));
        cache.set(url, 'current icon');
        events.push('body:' + url);
        return new ArrayBuffer(8);
      },
    };
  },
  _flutter: {loader: {async load(options) {
    events.push('loader');
    if (scenario.loaderFailure) throw new Error('entrypoint unavailable');
    // The real loader returns after script injection, before the callback.
    entrypointLoaded = options.onEntrypointLoaded;
  }}},
};
(async () => {
  await vm.runInNewContext(STARTUP_SOURCE, context);
  const app = entrypointLoaded ? entrypointLoaded({async initializeEngine() {
    events.push('engine');
    if (scenario.engineFailure) throw new Error('engine unavailable');
    return {async runApp() {
      events.push('app');
      if (scenario.appFailure) throw new Error('app unavailable');
    }};
  }}) : Promise.resolve();
  await new Promise(resolve => setImmediate(resolve));
  const beforeRelease = {events: [...events], requests: [...requests]};
  if (scenario.controllerChanged) {
    navigator.serviceWorker.controller = null;
  }
  releaseWorkers();
  releaseUnregister();
  releaseFont();
  await app;
  if (scenario.clickRetry && messages.length) {
    messages[0].children.find(child => child.tag === 'button').onclick();
  }
  process.stdout.write(JSON.stringify({
    requests, events, cache: [...cache], storageChanges, deadlines, unregistered,
    beforeRelease, failureMessages: messages.length,
  }));
})().catch(error => {console.error(error); process.exitCode = 1;});
"""


@unittest.skipUnless(NODE, 'Node.js is required to execute the browser startup regression tests')
class WebStartupIconCacheTest(unittest.TestCase):
    def run_startup(self, scenario=None):
        script = 'const STARTUP_SOURCE = ' + json.dumps(BUILD_WEB.STARTUP) + ';\n'
        result = subprocess.run(
            [NODE, '-e', script + STARTUP_HARNESS],
            input=json.dumps(scenario or {}), text=True, capture_output=True,
            check=True, timeout=10,
        )
        return json.loads(result.stdout)

    def test_refreshes_only_icon_assets_and_consumes_them_before_engine_start(self):
        result = self.run_startup()
        self.assertEqual(result['requests'], [
            {'url': 'https://snapfit.test/app/assets/FontManifest.json', 'cache': 'reload'},
            {'url': 'https://snapfit.test/app/assets/fonts/MaterialIcons-Regular.otf',
             'cache': 'reload'},
            {'url': 'https://snapfit.test/app/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
             'cache': 'reload'},
        ])
        self.assertEqual(len(result['cache']), 3)
        self.assertEqual(result['events'][0], 'loader')
        self.assertEqual(result['events'][-2:], ['engine', 'app'])
        self.assertEqual(len(result['events']), 5)
        self.assertEqual(result['storageChanges'], [])

    def test_manifest_failures_allow_the_engine_to_retry(self):
        for failure in ('network', 'status', 'json', 'shape'):
            with self.subTest(failure=failure):
                result = self.run_startup({'manifestFailure': failure})
                self.assertEqual(len(result['requests']), 1)
                self.assertEqual(result['events'], ['loader', 'engine', 'app'])
                self.assertEqual(result['storageChanges'], [])

    def test_one_failed_icon_does_not_skip_the_other_font_or_engine(self):
        for failure in ('network', 'status', 'body'):
            with self.subTest(failure=failure):
                result = self.run_startup({'fontFailure': failure})
                self.assertEqual(len(result['requests']), 3)
                self.assertEqual(result['events'][0], 'loader')
                self.assertEqual(result['events'][-2:], ['engine', 'app'])
                self.assertTrue(any('CupertinoIcons.ttf' in event
                                    for event in result['events'][1:-2]))
                self.assertEqual(result['storageChanges'], [])

    def test_stalled_refresh_aborts_within_the_budget_and_starts_engine(self):
        result = self.run_startup({'expire': True})
        self.assertEqual(result['deadlines'], [4000])
        self.assertEqual(result['events'], ['loader', 'engine', 'app'])
        self.assertEqual(result['storageChanges'], [])

    def test_entrypoint_starts_while_icon_fetch_is_held_but_engine_waits(self):
        result = self.run_startup({'holdFont': True})
        self.assertEqual(result['beforeRelease']['events'], ['loader'])
        self.assertEqual(len(result['beforeRelease']['requests']), 3)
        self.assertEqual(result['events'][-2:], ['engine', 'app'])
        self.assertEqual(len(result['cache']), 3)

    def test_entrypoint_starts_while_worker_query_is_held_but_engine_waits(self):
        result = self.run_startup({'holdWorkers': True})
        self.assertEqual(result['beforeRelease']['events'], ['worker-query', 'loader'])
        self.assertEqual(result['beforeRelease']['requests'], [])
        self.assertEqual(result['events'][-2:], ['engine', 'app'])
        self.assertEqual(result['unregistered'], ['generated'])

    def test_entrypoint_starts_while_unregistration_is_held_but_engine_waits(self):
        result = self.run_startup({'holdUnregister': True})
        self.assertIn('loader', result['beforeRelease']['events'])
        self.assertIn('unregister-start:generated', result['beforeRelease']['events'])
        self.assertNotIn('engine', result['beforeRelease']['events'])
        self.assertEqual(result['beforeRelease']['requests'], [])
        self.assertEqual(result['events'][-2:], ['engine', 'app'])

    def test_stalled_worker_api_has_a_budget_and_does_not_block_app(self):
        result = self.run_startup({'workerTimeout': True})
        self.assertEqual(result['deadlines'], [500, 4000])
        self.assertLess(result['events'].index('loader'), result['events'].index('engine'))
        self.assertEqual(result['events'][-2:], ['engine', 'app'])
        self.assertEqual(result['storageChanges'], [])

    def test_only_exact_generated_worker_is_retired_and_browser_failure_is_tolerated(self):
        result = self.run_startup({'workers': True})
        self.assertEqual(result['unregistered'], ['generated'])
        self.assertEqual(result['storageChanges'], [])
        result = self.run_startup({'workerFailure': True})
        self.assertEqual(result['events'][-2:], ['engine', 'app'])
        self.assertEqual(result['failureMessages'], 0)

    def test_loader_engine_and_app_failures_show_a_retry_without_clearing_storage(self):
        for failure in ('loaderFailure', 'engineFailure', 'appFailure'):
            with self.subTest(failure=failure):
                result = self.run_startup({failure: True, 'clickRetry': True})
                self.assertEqual(result['failureMessages'], 1)
                self.assertEqual(result['events'][-1], 'reload')
                self.assertEqual(result['storageChanges'], [])

    def test_confirmed_current_generated_worker_reloads_once_before_engine(self):
        result = self.run_startup({'controlled': True})
        self.assertEqual(result['unregistered'], ['generated'])
        self.assertEqual(result['events'].count('reload'), 1)
        self.assertNotIn('engine', result['events'])
        self.assertNotIn('app', result['events'])
        self.assertEqual(result['requests'], [])
        self.assertEqual(result['storageChanges'], [])

    def test_next_document_after_retirement_starts_engine_without_another_reload(self):
        result = self.run_startup({'alreadyRetired': True})
        self.assertEqual(result['events'][-2:], ['engine', 'app'])
        self.assertNotIn('reload', result['events'])
        self.assertEqual(result['unregistered'], [])
        self.assertEqual(result['storageChanges'], [])

    def test_failed_or_timed_out_retirement_never_reloads(self):
        for failure in ('unregisterFailure', 'unregisterError', 'workerTimeout',
                        'unregisterTimeout'):
            with self.subTest(failure=failure):
                result = self.run_startup({'controlled': True, failure: True})
                self.assertEqual(result['events'][-2:], ['engine', 'app'])
                self.assertNotIn('reload', result['events'])
                self.assertEqual(result['storageChanges'], [])

    def test_other_controller_or_registration_scope_never_reloads(self):
        for scenario in ({'controllerKind': 'firebase'},
                         {'controllerKind': 'other-origin'},
                         {'controlled': True, 'otherScope': True}):
            with self.subTest(scenario=scenario):
                result = self.run_startup(scenario)
                self.assertEqual(result['events'][-2:], ['engine', 'app'])
                self.assertNotIn('reload', result['events'])
                self.assertEqual(result['storageChanges'], [])

    def test_controller_released_before_cleanup_completes_needs_no_reload(self):
        result = self.run_startup({'controlled': True, 'holdWorkers': True,
                                   'controllerChanged': True})
        self.assertEqual(result['unregistered'], ['generated'])
        self.assertEqual(result['events'][-2:], ['engine', 'app'])
        self.assertNotIn('reload', result['events'])


class WebReleaseCompatibilityTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / 'build/review-web'
        self.output.mkdir(parents=True)
        self.history = self.root / 'history'

    def entrypoint(self, prefix, content, folder=None):
        digest = hashlib.sha256(content).hexdigest()[:20]
        suffix = '.dart.js' if prefix == 'main' else '.js'
        name = f'{prefix}.{digest}{suffix}'
        ((folder or self.output) / name).write_bytes(content)
        return name

    def fresh_build(self):
        (self.output / 'main.dart.js').write_bytes(b'current app code')
        (self.output / 'flutter_bootstrap.js').write_text(
            '_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]};'
            '_flutter.loader.load();',
        )
        (self.output / 'index.html').write_text(
            '<html><head><base href="/app/"></head><body>'
            '<script src="flutter_bootstrap.js" async></script></body></html>',
        )

    def test_preload_and_loader_use_the_same_content_addressed_main(self):
        self.fresh_build()
        result = BUILD_WEB.fingerprint_build(self.output)
        html = (self.output / 'index.html').read_text()
        script = (self.output / result['bootstrap_file']).read_text()
        preload = (f'<link rel="preload" href="{result["main_file"]}" '
                   'as="script" fetchpriority="high">')
        self.assertIn(preload, html)
        self.assertLess(html.index(preload), html.index('</head>'))
        self.assertLess(html.index(preload), html.index('<script'))
        self.assertIn('<base href="/app/">', html)
        self.assertIn(f'src="{result["bootstrap_file"]}"', html)
        self.assertIn(f'"mainJsPath":"{result["main_file"]}"', script)
        self.assertIn('onEntrypointLoaded: async', script)
        self.assertEqual(
            hashlib.sha256((self.output / result['main_file']).read_bytes()).hexdigest(),
            result['main_sha256'],
        )
        self.assertEqual(
            hashlib.sha256(script.encode()).hexdigest(), result['bootstrap_sha256'],
        )

    def test_preload_requires_one_unambiguous_html_head(self):
        self.fresh_build()
        (self.output / 'index.html').write_text(
            '<script src="flutter_bootstrap.js"></script>',
        )
        with self.assertRaisesRegex(RuntimeError, 'Unexpected Flutter HTML head'):
            BUILD_WEB.fingerprint_build(self.output)
        self.assertEqual(list(self.output.glob('main.*.dart.js')), [])

    def test_preloads_only_current_document_fonts_with_matching_fetch_mode(self):
        self.fresh_build()
        fonts = [hashlib.sha256(f'font {index}'.encode()).hexdigest()[:20] +
                 ('.otf' if index == 39 else '.ttf') for index in range(40)]
        assets = self.output / 'assets'
        (assets / 'web_fonts').mkdir(parents=True)
        # Retained fonts are available to old tabs, but are not current requests.
        retired = hashlib.sha256(b'retired font').hexdigest()[:20] + '.ttf'
        (assets / 'web_fonts' / retired).write_bytes(b'retired font')
        manifest = [{
            'family': f'Document {index}',
            'fonts': [{'asset': 'web_fonts/' + name, 'weight': 400}],
        } for index, name in enumerate(fonts)]
        manifest.extend([
            {'family': 'Alias', 'fonts': [{'asset': 'web_fonts/' + fonts[0]}]},
            {'family': 'MaterialIcons', 'fonts': [{'asset': 'fonts/MaterialIcons-Regular.otf'}]},
            {'family': 'CupertinoIcons', 'fonts': [{'asset': 'packages/cupertino_icons/icons.ttf'}]},
            {'family': 'Neumorphic', 'fonts': [{'asset': 'packages/neumorphic/icons.ttf'}]},
        ])
        (assets / 'FontManifest.json').write_text(json.dumps(manifest))
        result = BUILD_WEB.fingerprint_build(self.output)
        html = (self.output / 'index.html').read_text()
        self.assertEqual(html.count('as="fetch" crossorigin="anonymous" fetchpriority="low"'), 40)
        for name in fonts:
            self.assertEqual(html.count(f'href="assets/web_fonts/{name}"'), 1)
        self.assertNotIn(retired, html)
        self.assertNotIn('MaterialIcons-Regular.otf', html)
        self.assertNotIn('packages/', html)
        self.assertLess(html.index(result['main_file']), html.index('as="fetch"'))
        self.assertLess(html.rindex('as="fetch"'), html.index('</head>'))

    def test_old_entrypoints_survive_a_rebuilt_output(self):
        old_main = self.entrypoint('main', b'old immutable main')
        old_bootstrap = self.entrypoint('flutter_bootstrap', b'old startup')
        (self.output / 'index.html').write_text('old html')
        BUILD_WEB.preserve_entrypoints(self.output, self.history)
        shutil.rmtree(self.output)
        self.output.mkdir()
        (self.output / 'index.html').write_text('new html')
        new_main = self.entrypoint('main', b'new immutable main')
        BUILD_WEB.restore_entrypoints(self.output, self.history)
        self.assertEqual((self.output / old_main).read_bytes(), b'old immutable main')
        self.assertEqual((self.output / old_bootstrap).read_bytes(), b'old startup')
        self.assertEqual((self.output / new_main).read_bytes(), b'new immutable main')
        self.assertEqual((self.output / 'index.html').read_text(), 'new html')

    def test_corrupt_content_cannot_be_preserved_under_an_immutable_name(self):
        (self.output / ('main.' + '0' * 20 + '.dart.js')).write_bytes(b'wrong hash')
        with self.assertRaisesRegex(RuntimeError, 'content hash mismatch'):
            BUILD_WEB.preserve_entrypoints(self.output, self.history)

    def test_old_html_redirects_to_latest_bootstrap_after_each_build(self):
        old = self.entrypoint('flutter_bootstrap', b'old startup')
        current = self.entrypoint('flutter_bootstrap', b'current startup')
        unrelated = {'source': '/previous', 'destination': '/feed', 'type': 302}
        config = self.root / 'firebase.json'
        config.write_text(json.dumps({'hosting': {
            'public': 'build/review-web',
            'redirects': [unrelated, {
                'source': '/flutter_bootstrap.' + 'a' * 20 + '.js',
                'destination': '/' + old, 'type': 302,
            }],
        }}))
        BUILD_WEB.update_hosting_bootstrap_redirects(self.output, current, config)
        redirects = json.loads(config.read_text())['hosting']['redirects']
        self.assertIn(unrelated, redirects)
        self.assertIn({'source': '/' + old, 'destination': '/' + current, 'type': 302}, redirects)
        self.assertFalse(any(item['source'] == '/flutter_bootstrap.' + 'a' * 20 + '.js'
                             for item in redirects))
        self.assertFalse(any(item['source'] == '/' + current for item in redirects))
        newest = self.entrypoint('flutter_bootstrap', b'newest startup')
        BUILD_WEB.update_hosting_bootstrap_redirects(self.output, newest, config)
        redirects = json.loads(config.read_text())['hosting']['redirects']
        managed = [item for item in redirects if item['source'].startswith('/flutter_bootstrap.')]
        self.assertTrue(all(item['destination'] == '/' + newest for item in managed))
        self.assertTrue(any(item['source'] == '/' + current for item in managed))

    def test_retention_keeps_only_the_three_most_recent_distinct_release_pairs(self):
        releases = []
        for number in range(5):
            main = self.entrypoint('main', f'main {number}'.encode())
            bootstrap = self.entrypoint(
                'flutter_bootstrap', json.dumps(
                    {'mainJsPath': main}, separators=(',', ':'),
                ).encode(),
            )
            current = {'main_file': main, 'bootstrap_file': bootstrap}
            releases.append(current)
            BUILD_WEB.preserve_entrypoints(self.output, self.history)
            BUILD_WEB.record_entrypoint_release(self.output, current, self.history)
            BUILD_WEB.restore_entrypoints(self.output, self.history)
        retained = json.loads((self.history / 'releases.json').read_text())
        self.assertEqual(retained, releases[-3:])
        expected = {name for release in releases[-3:] for name in release.values()}
        self.assertEqual({file.name for file in self.history.glob('*.js')}, expected)
        self.assertEqual({file.name for file in self.output.glob('*.js')}, expected)
        BUILD_WEB.record_entrypoint_release(self.output, releases[-1], self.history)
        self.assertEqual(json.loads((self.history / 'releases.json').read_text()), retained)

    def test_local_preview_build_does_not_change_hosting_redirects(self):
        config = self.root / 'firebase.json'
        original = json.dumps({'hosting': {'public': 'build/production'}})
        config.write_text(original)
        BUILD_WEB.update_hosting_bootstrap_redirects(
            self.output, 'flutter_bootstrap.' + 'f' * 20 + '.js', config,
        )
        self.assertEqual(config.read_text(), original)

    def test_preview_releases_cannot_evict_the_production_history(self):
        preview = self.root / 'build/preview'
        preview.mkdir()
        with mock.patch.object(BUILD_WEB, 'ENTRYPOINT_HISTORY', self.root / 'histories'):
            production_history = BUILD_WEB.entrypoint_history_for(self.output)
            preview_history = BUILD_WEB.entrypoint_history_for(preview)
            self.assertNotEqual(production_history, preview_history)
            main = self.entrypoint('main', b'production main')
            bootstrap = self.entrypoint(
                'flutter_bootstrap', json.dumps(
                    {'mainJsPath': main}, separators=(',', ':'),
                ).encode(),
            )
            production = {'main_file': main, 'bootstrap_file': bootstrap}
            BUILD_WEB.preserve_entrypoints(self.output, production_history)
            BUILD_WEB.record_entrypoint_release(self.output, production, production_history)
            for number in range(4):
                preview_main = self.entrypoint('main', f'preview {number}'.encode(), preview)
                preview_bootstrap = self.entrypoint(
                    'flutter_bootstrap', json.dumps(
                        {'mainJsPath': preview_main}, separators=(',', ':'),
                    ).encode(), preview,
                )
                current = {'main_file': preview_main, 'bootstrap_file': preview_bootstrap}
                BUILD_WEB.preserve_entrypoints(preview, preview_history)
                BUILD_WEB.record_entrypoint_release(preview, current, preview_history)
            self.assertEqual(
                json.loads((production_history / 'releases.json').read_text()),
                [production],
            )
            self.assertEqual((production_history / main).read_bytes(), b'production main')


class WebFontReleaseCompatibilityTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / 'build/review-web'
        self.output.mkdir(parents=True)
        self.history = self.root / 'font-history'

    def font(self, data, output=None, extension='.woff2'):
        name = hashlib.sha256(data).hexdigest()[:20] + extension
        folder = (output or self.output) / 'assets/web_fonts'
        folder.mkdir(parents=True, exist_ok=True)
        (folder / name).write_bytes(data)
        return name

    def manifest(self, names, output=None):
        path = (output or self.output) / 'assets/FontManifest.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps([{
            'family': 'Document',
            'fonts': [{'asset': 'web_fonts/' + name, 'weight': 400} for name in names],
        }]))

    def test_fonts_referenced_by_an_old_manifest_survive_a_fresh_build(self):
        old = self.font(b'original complete font')
        self.manifest([old])
        BUILD_WEB.preserve_web_fonts(self.output, self.history)
        shutil.rmtree(self.output)
        new = self.font(b'new complete font')
        self.manifest([new])
        BUILD_WEB.preserve_web_fonts(self.output, self.history)
        BUILD_WEB.restore_web_font_releases(self.output, self.history)
        self.assertEqual((self.output / 'assets/web_fonts' / old).read_bytes(),
                         b'original complete font')
        self.assertEqual((self.output / 'assets/web_fonts' / new).read_bytes(),
                         b'new complete font')
        self.assertEqual(BUILD_WEB._referenced_web_fonts(self.output), [new])

    def test_retention_keeps_three_distinct_sets_and_preserves_original_fonts(self):
        shared = self.font(b'shared complete font')
        source = self.output / 'assets/assets/fonts/Original.ttf'
        source.parent.mkdir(parents=True)
        source.write_bytes(b'unchanged original sfnt')
        generations = []
        for number in range(5):
            current = sorted([shared, self.font(f'complete font {number}'.encode())])
            generations.append(current)
            self.manifest(current)
            BUILD_WEB.preserve_web_fonts(self.output, self.history)
            BUILD_WEB.restore_web_font_releases(self.output, self.history)
        expected = {name for generation in generations[-3:] for name in generation}
        self.assertEqual({file.name for file in self.history.glob('*.woff2')}, expected)
        self.assertEqual({file.name for file in
                          (self.output / 'assets/web_fonts').glob('*.woff2')}, expected)
        self.assertEqual(json.loads((self.history / 'releases.json').read_text()),
                         generations[-3:])
        self.assertEqual(source.read_bytes(), b'unchanged original sfnt')
        # An unchanged set must not consume another compatibility generation.
        for _ in range(3):
            BUILD_WEB.preserve_web_fonts(self.output, self.history)
            BUILD_WEB.restore_web_font_releases(self.output, self.history)
        self.assertEqual(json.loads((self.history / 'releases.json').read_text()),
                         generations[-3:])

    def test_original_sfnt_rollout_retains_previous_woff_urls_for_three_generations(self):
        def release(names):
            self.manifest(names)
            BUILD_WEB.preserve_web_fonts(self.output, self.history)
            BUILD_WEB.restore_web_font_releases(self.output, self.history)

        woff = self.font(b'previous woff2 font')
        release([woff])
        ttf = self.font(b'original ttf font', extension='.ttf')
        otf = self.font(b'original otf font', extension='.otf')
        release([ttf, otf])
        replacement = self.font(b'replacement ttf font', extension='.ttf')
        release([replacement, otf])
        retained = {woff, ttf, otf, replacement}
        folder = self.output / 'assets/web_fonts'
        self.assertEqual({file.name for file in folder.glob('*')}, retained)
        for name in retained:
            BUILD_WEB._verify_web_font(folder / name)
        current = self.font(b'latest ttf font', extension='.ttf')
        release([current, otf])
        self.assertEqual({file.name for file in folder.glob('*')},
                         {ttf, otf, replacement, current})
        self.assertFalse((self.history / woff).exists())

    def test_corrupt_font_cannot_be_archived_under_an_immutable_url(self):
        name = self.font(b'complete font')
        (self.output / 'assets/web_fonts' / name).write_bytes(b'changed content')
        self.manifest([name])
        with self.assertRaisesRegex(RuntimeError, 'content hash mismatch'):
            BUILD_WEB.preserve_web_fonts(self.output, self.history)

    def test_missing_or_corrupt_retained_font_fails_before_pruning(self):
        for corrupt in (False, True):
            with self.subTest(corrupt=corrupt):
                name = self.font(b'complete font')
                self.manifest([name])
                BUILD_WEB.preserve_web_fonts(self.output, self.history)
                cached = self.history / name
                cached.write_bytes(b'corrupt') if corrupt else cached.unlink()
                with self.assertRaisesRegex(RuntimeError, 'content hash mismatch'):
                    BUILD_WEB.restore_web_font_releases(self.output, self.history)
                self.assertEqual((self.output / 'assets/web_fonts' / name).read_bytes(),
                                 b'complete font')

    def test_invalid_manifest_font_path_cannot_escape_the_archive(self):
        self.manifest(['../escape.woff2'])
        with self.assertRaisesRegex(RuntimeError, 'Unsafe web font path'):
            BUILD_WEB.preserve_web_fonts(self.output, self.history)

    def test_preview_builds_cannot_evict_production_font_history(self):
        preview = self.root / 'build/preview'
        with mock.patch.object(BUILD_WEB, 'FONT_HISTORY', self.root / 'histories'):
            production_history = BUILD_WEB.font_history_for(self.output)
            preview_history = BUILD_WEB.font_history_for(preview)
            self.assertNotEqual(production_history, preview_history)
            production = self.font(b'production font')
            self.manifest([production])
            BUILD_WEB.preserve_web_fonts(self.output, production_history)
            BUILD_WEB.restore_web_font_releases(self.output, production_history)
            for number in range(5):
                current = self.font(f'preview font {number}'.encode(), preview)
                self.manifest([current], preview)
                BUILD_WEB.preserve_web_fonts(preview, preview_history)
                BUILD_WEB.restore_web_font_releases(preview, preview_history)
            self.assertEqual((production_history / production).read_bytes(), b'production font')
            self.assertEqual(json.loads((production_history / 'releases.json').read_text()),
                             [[production]])

    def test_verified_font_helper_metadata_is_published(self):
        tool = self.root / 'tool/pack_web_fonts.py'
        tool.parent.mkdir()
        tool.write_text(
            "def rewrite_web_font_manifest(output):\n"
            "    return {'documentFontFiles': 40, 'sourceBytes': 100, 'packedBytes': 30, "
            "'legacyPathsPreserved': True}\n",
        )
        with mock.patch.object(BUILD_WEB, 'ROOT', self.root):
            result = BUILD_WEB.package_web_document_fonts(self.output)
        self.assertEqual(json.loads((self.output / 'snapfit-web-font-pack.json').read_text()),
                         result)
        self.assertEqual(result['documentFontFiles'], 40)

    def test_unverified_font_failure_propagates_without_publishing_metadata(self):
        tool = self.root / 'tool/pack_web_fonts.py'
        tool.parent.mkdir()
        tool.write_text(
            "def rewrite_web_font_manifest(output):\n"
            "    raise RuntimeError('New document font needs a web pack')\n",
        )
        with mock.patch.object(BUILD_WEB, 'ROOT', self.root):
            with self.assertRaisesRegex(RuntimeError, 'New document font'):
                BUILD_WEB.package_web_document_fonts(self.output)
        self.assertFalse((self.output / 'snapfit-web-font-pack.json').exists())

    def test_build_pipeline_packages_before_fingerprinting_and_restores_old_font_urls(self):
        old = self.font(b'old complete document font')
        self.manifest([old])
        (self.output / 'main.dart.js').write_bytes(b'current app code')
        (self.output / 'flutter_bootstrap.js').write_text(
            '_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]};'
            '_flutter.loader.load();',
        )
        (self.output / 'index.html').write_text(
            '<html><head></head><body>'
            '<script src="flutter_bootstrap.js" async></script></body></html>',
        )
        events = []
        current = None
        fingerprint = BUILD_WEB.fingerprint_build

        def package(output):
            nonlocal current
            events.append('verified-font-pack')
            current = self.font(b'new complete document font')
            self.manifest([current])
            return {'legacyPathsPreserved': True}

        def fingerprint_after_pack(output, startup_font_manifest=None):
            events.append('fingerprint')
            self.assertEqual(BUILD_WEB._referenced_web_fonts(output), [current])
            return fingerprint(output)

        with (
            mock.patch.object(sys, 'argv', ['build_web', '--existing-build',
                                           '--output', str(self.output)]),
            mock.patch.object(BUILD_WEB, 'ENTRYPOINT_HISTORY', self.root / 'entry-histories'),
            mock.patch.object(BUILD_WEB, 'FONT_HISTORY', self.root / 'font-histories'),
            mock.patch.object(BUILD_WEB, 'package_web_document_fonts', side_effect=package),
            mock.patch.object(BUILD_WEB, 'fingerprint_build', side_effect=fingerprint_after_pack),
            mock.patch.object(BUILD_WEB, 'update_hosting_bootstrap_redirects'),
            mock.patch('builtins.print'),
        ):
            BUILD_WEB.main()
        self.assertEqual(events, ['verified-font-pack', 'fingerprint'])
        self.assertEqual((self.output / 'assets/web_fonts' / old).read_bytes(),
                         b'old complete document font')
        self.assertEqual((self.output / 'assets/web_fonts' / current).read_bytes(),
                         b'new complete document font')


if __name__ == '__main__':
    unittest.main()
