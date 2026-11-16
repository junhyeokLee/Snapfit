import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('build_web', ROOT / 'tool/build_web.py')
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)
NODE = shutil.which('node')


class StartupManifestTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / 'build/web'
        self.assets = self.output / 'assets'
        self.assets.mkdir(parents=True)
        self.declarations = []
        self.mapping = {}
        self.full = []
        for family in ['NotoSans', 'Roboto', 'Poppins', 'Raleway', 'Saved Album']:
            asset = 'assets/fonts/' + family + '.ttf'
            source = self.root / asset
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(('original bytes: ' + family).encode())
            hashed = 'web_fonts/' + hashlib.sha256(source.read_bytes()).hexdigest()[:20] + '.ttf'
            self.mapping[asset] = hashed
            entry = {'family': family, 'fonts': [{'asset': asset, 'weight': 600}]}
            self.declarations.append(entry)
            entry = copy.deepcopy(entry)
            entry['fonts'][0]['asset'] = hashed
            self.full.append(entry)
        self.full.extend([
            {'family': 'MaterialIcons', 'fonts': [{'asset': 'fonts/MaterialIcons-Regular.otf'}]},
            {'family': 'packages/other/icons', 'fonts': [{'asset': 'packages/other/icons.ttf'}]},
        ])
        self.manifest = self.assets / 'FontManifest.json'
        self.manifest.write_text(json.dumps(self.full))
        self.write_declarations()

    def write_declarations(self):
        folder = self.root / 'lib/core/fonts'
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'document_font_manifest.dart').write_text(
            "const documentFontManifestJson = r'''" + json.dumps(self.declarations) + "''';")
        (folder / 'document_font_assets.dart').write_text(
            "const documentFontAssetPathsJson = r'''" + json.dumps(self.mapping) + "''';")
        (folder / 'document_fonts.dart').write_text(
            'static const startupFamilies = {' +
            ','.join(repr(name) for name in sorted(BUILD.STARTUP_FONT_FAMILIES)) + '};')

    def test_engine_subset_keeps_full_public_manifest_and_every_descriptor(self):
        before = self.manifest.read_bytes()
        asset = BUILD.package_startup_font_manifest(self.output, root=self.root)
        self.assertEqual(self.manifest.read_bytes(), before)
        subset = json.loads((self.output / asset).read_text())
        self.assertEqual(subset, [entry for entry in self.full if entry['family'] != 'Saved Album'])
        self.assertEqual(hashlib.sha256((self.output / asset).read_bytes()).hexdigest()[:20],
                         Path(asset).name.split('.')[1])

    def test_changed_family_alias_or_weight_fails_closed(self):
        self.declarations[-1]['fonts'][0]['weight'] = 700
        self.write_declarations()
        with self.assertRaisesRegex(RuntimeError, 'declarations differ'):
            BUILD.package_startup_font_manifest(self.output, root=self.root)
        self.assertEqual(list(self.assets.glob('StartupFontManifest.*')), [])

    def test_changed_dynamic_loader_hash_fails_closed(self):
        self.mapping['assets/fonts/Saved Album.ttf'] = 'web_fonts/' + '0' * 20 + '.ttf'
        self.write_declarations()
        with self.assertRaisesRegex(RuntimeError, 'mappings differ'):
            BUILD.package_startup_font_manifest(self.output, root=self.root)

    def test_dart_and_engine_ready_families_cannot_drift(self):
        path = self.root / 'lib/core/fonts/document_fonts.dart'
        path.write_text("static const startupFamilies = {'NotoSans'};")
        with self.assertRaisesRegex(RuntimeError, 'startup font families differ'):
            BUILD.package_startup_font_manifest(self.output, root=self.root)

    def test_only_interface_fonts_are_preloaded_and_bootstrap_references_subset(self):
        initial = BUILD.package_startup_font_manifest(self.output, root=self.root)
        (self.output / 'main.dart.js').write_text('unchanged application')
        (self.output / 'flutter_bootstrap.js').write_text(
            'const config={"mainJsPath":"main.dart.js"};_flutter.loader.load();')
        (self.output / 'index.html').write_text(
            '<html><head></head><body><script src="flutter_bootstrap.js"></script></body></html>')
        result = BUILD.fingerprint_build(self.output, initial)
        html = (self.output / 'index.html').read_text()
        self.assertNotIn(self.mapping['assets/fonts/Saved Album.ttf'], html)
        for name in ['NotoSans', 'Roboto', 'Poppins', 'Raleway']:
            self.assertIn(self.mapping['assets/fonts/' + name + '.ttf'], html)
        script = (self.output / result['bootstrap_file']).read_text()
        self.assertIn(json.dumps(initial), script)
        self.assertIn('finally', script)

    def test_three_startup_manifests_survive_rebuilt_output_with_full_font_set(self):
        history = self.root / 'history'
        for original, hashed in self.mapping.items():
            destination = self.assets / hashed
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(self.root / original, destination)
        names = []
        for generation in range(4):
            data = json.dumps([{'startupGeneration': generation}]).encode()
            name = 'StartupFontManifest.' + hashlib.sha256(data).hexdigest()[:20] + '.json'
            names.append(name)
            (self.assets / name).write_bytes(data)
            BUILD.preserve_web_fonts(self.output, history)
            shutil.rmtree(self.output)
            self.assets.mkdir(parents=True)
            self.manifest.write_text(json.dumps(self.full))
            BUILD.restore_web_font_releases(self.output, history)
            self.assertEqual({p.name for p in self.assets.glob('StartupFontManifest.*.json')},
                             set(names[-3:]))
            for hashed in self.mapping.values():
                self.assertTrue((self.assets / hashed).is_file())


@unittest.skipUnless(NODE, 'Node is required for bootstrap lifecycle verification')
class TemporaryFetchMappingTests(unittest.TestCase):
    def run_scenario(self, fails=False):
        source = BUILD.STARTUP.replace(
            'const initialFontManifest = null; // SNAPFIT_ENGINE_FONT_MANIFEST',
            'const initialFontManifest = "assets/StartupFontManifest.fixture.json";')
        harness = r'''
const vm = require('node:vm');
const requests = [];
let phase = 'prepare';
let errors = 0;
const originalFetch = async (input, options) => {
  requests.push({url: typeof input === 'string' ? input : input.url,
    method: options?.method || input.method || 'GET',
    header: input.headers?.get('x-snapfit'), phase});
  return {ok:true, json:async()=>[], arrayBuffer:async()=>new ArrayBuffer(0)};
};
const context = {URL, Request, AbortController, setTimeout, clearTimeout,
  fetch: originalFetch, navigator:{}, location:{reload(){}},
  document:{baseURI:'https://snapfit.test/app/',
    createElement(){return {style:{},append(){}};},body:{append(){errors++;}}},
  _flutter:{loader:{async load(options){
    await options.onEntrypointLoaded({async initializeEngine(){
      phase = 'engine';
      const full = 'https://snapfit.test/app/assets/FontManifest.json';
      await context.fetch(full);
      await context.fetch(new Request(full,{headers:{'x-snapfit':'preserved'}}));
      await context.fetch(full,{method:'POST'});
      await context.fetch(full+'?different=1');
      await context.fetch('https://other.test/app/assets/FontManifest.json');
      await context.fetch('https://snapfit.test/app/assets/photo.jpg');
      if (FAILS) throw Error('engine failure');
      return {async runApp(){
        phase = 'app';
        await context.fetch(full);
      }};
    }});
  }}}
};
(async()=>{
  await vm.runInNewContext(SOURCE,context);
  phase='after';
  await context.fetch('https://snapfit.test/app/assets/FontManifest.json');
  process.stdout.write(JSON.stringify({requests,restored:context.fetch===originalFetch,errors}));
})();
'''.replace('SOURCE', json.dumps(source)).replace('FAILS', json.dumps(fails))
        result = subprocess.run([NODE, '-e', harness], capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    def test_only_engine_exact_get_is_mapped_and_request_headers_survive(self):
        result = self.run_scenario()
        self.assertTrue(result['restored'])
        engine = [r for r in result['requests'] if r['phase'] == 'engine']
        initial = 'https://snapfit.test/app/assets/StartupFontManifest.fixture.json'
        self.assertEqual([r['url'] for r in engine[:2]], [initial, initial])
        self.assertEqual(engine[1]['header'], 'preserved')
        self.assertEqual(engine[2]['method'], 'POST')
        self.assertTrue(engine[2]['url'].endswith('/FontManifest.json'))
        self.assertTrue(engine[3]['url'].endswith('?different=1'))
        self.assertTrue(engine[4]['url'].startswith('https://other.test'))
        self.assertTrue(engine[5]['url'].endswith('photo.jpg'))
        self.assertTrue(all(r['url'].endswith('/FontManifest.json')
                            for r in result['requests'] if r['phase'] in ('app','after')))
        self.assertEqual(result['errors'], 0)

    def test_failed_engine_also_restores_full_manifest_and_retry_ui(self):
        result = self.run_scenario(fails=True)
        self.assertTrue(result['restored'])
        self.assertEqual(result['errors'], 1)
        self.assertTrue(result['requests'][-1]['url'].endswith('/FontManifest.json'))


if __name__ == '__main__':
    unittest.main()
