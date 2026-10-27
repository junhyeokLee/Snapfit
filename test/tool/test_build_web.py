import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
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
let deadline;
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
const context = {
  URL, AbortController,
  navigator: {},
  document: {baseURI: 'https://snapfit.test/app/'},
  localStorage: {clear: () => storageChanges.push('localStorage')},
  caches: {delete: () => storageChanges.push('caches')},
  setTimeout(callback, delay) {
    deadline = delay;
    return setTimeout(callback, scenario.expire ? 0 : delay);
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
  _flutter: {loader: {async load() {events.push('loader');}}},
};
(async () => {
  await vm.runInNewContext(STARTUP_SOURCE, context);
  process.stdout.write(JSON.stringify({
    requests, events, cache: [...cache], storageChanges, deadline,
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
        self.assertEqual(result['events'][-1], 'loader')
        self.assertEqual(len(result['events']), 3)
        self.assertEqual(result['storageChanges'], [])

    def test_manifest_failures_allow_the_engine_to_retry(self):
        for failure in ('network', 'status', 'json', 'shape'):
            with self.subTest(failure=failure):
                result = self.run_startup({'manifestFailure': failure})
                self.assertEqual(len(result['requests']), 1)
                self.assertEqual(result['events'], ['loader'])
                self.assertEqual(result['storageChanges'], [])

    def test_one_failed_icon_does_not_skip_the_other_font_or_engine(self):
        for failure in ('network', 'status', 'body'):
            with self.subTest(failure=failure):
                result = self.run_startup({'fontFailure': failure})
                self.assertEqual(len(result['requests']), 3)
                self.assertEqual(result['events'][-1], 'loader')
                self.assertTrue(any('CupertinoIcons.ttf' in event
                                    for event in result['events'][:-1]))
                self.assertEqual(result['storageChanges'], [])

    def test_stalled_refresh_aborts_within_the_budget_and_starts_engine(self):
        result = self.run_startup({'expire': True})
        self.assertEqual(result['deadline'], 4000)
        self.assertEqual(result['events'], ['loader'])
        self.assertEqual(result['storageChanges'], [])


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


if __name__ == '__main__':
    unittest.main()
