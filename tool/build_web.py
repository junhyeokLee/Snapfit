#!/usr/bin/env python3
"""Build the existing Flutter app with content-addressed browser entrypoints.

Old Flutter service workers can otherwise serve an obsolete main.dart.js even
after a reload. No login storage, cookies, albums or user files are removed.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ENTRYPOINT_HISTORY = ROOT / '.dart_tool' / 'web_entrypoint_history'
ENTRYPOINT_GENERATIONS = 3
ENTRYPOINT_PATTERN = re.compile(
    r'^(?:main\.([0-9a-f]{20})\.dart|flutter_bootstrap\.([0-9a-f]{20}))\.js$'
)
FONT_HISTORY = ROOT / '.dart_tool' / 'web_font_history'
FONT_GENERATIONS = 3
FONT_PATTERN = re.compile(r'^([0-9a-f]{20})\.(?:ttf|otf|woff2)$')
FONT_SUFFIXES = frozenset({'.ttf', '.otf', '.woff2'})
STARTUP_MANIFEST_PATTERN = re.compile(r'^StartupFontManifest\.([0-9a-f]{20})\.json$')
STARTUP_FONT_FAMILIES = frozenset({
    'NotoSans', 'Roboto', 'Poppins', 'Raleway',
    'MaterialIcons', 'CupertinoIcons', 'packages/cupertino_icons/CupertinoIcons',
})
STARTUP = r"""
(async () => {
  const initialFontManifest = null; // SNAPFIT_ENGINE_FONT_MANIFEST

  async function initializeWithInterfaceFonts(engineInitializer) {
    if (!initialFontManifest) return engineInitializer.initializeEngine();
    // The public full manifest must stay complete: an already-open older tab
    // reads it later for printing/publication. Only the engine's initial GET
    // uses the small, immutable interface manifest. Restore fetch before Dart
    // main/runApp, including initialization failure; every other URL is intact.
    const originalFetch = globalThis.fetch;
    const full = new URL('assets/FontManifest.json', document.baseURI).href;
    const initial = new URL(initialFontManifest, document.baseURI).href;
    function interfaceFetch(input, options) {
      let mapped = input;
      try {
        const url = new URL(typeof input === 'string' || input instanceof URL
          ? input : input.url, document.baseURI);
        const method = options?.method || input?.method || 'GET';
        if (url.href === full && method.toUpperCase() === 'GET') {
          mapped = typeof input === 'string' || input instanceof URL
            ? initial : new Request(initial, input);
        }
      } catch (_) { /* Preserve normal fetch validation for all other input. */ }
      return originalFetch.call(globalThis, mapped, options);
    }
    globalThis.fetch = interfaceFetch;
    try {
      return await engineInitializer.initializeEngine();
    } finally {
      if (globalThis.fetch === interfaceFetch) globalThis.fetch = originalFetch;
    }
  }

  async function prepareAssetCache() {
    // Retire only this app's generated Flutter worker. Other worker scopes and
    // all authentication/document storage remain intact. A stalled browser API
    // must not prevent startup; late cleanup may safely finish in the background.
    try {
      if ('serviceWorker' in navigator) {
        let timer;
        try {
          const controller = navigator.serviceWorker.controller;
          const cleanup = (async () => {
            const base = new URL('.', document.baseURI);
            const workerUrl = new URL('flutter_service_worker.js', base);
            const controllerUrl = controller ? new URL(controller.scriptURL) : null;
            const controlsThisApp = controllerUrl &&
              controllerUrl.origin === workerUrl.origin &&
              controllerUrl.pathname === workerUrl.pathname;
            const registrations = await navigator.serviceWorker.getRegistrations();
            const retired = await Promise.all(registrations.filter(registration => {
              const worker = registration.active || registration.waiting || registration.installing;
              if (!worker || registration.scope !== base.href) return false;
              const url = new URL(worker.scriptURL);
              return url.origin === workerUrl.origin && url.pathname === workerUrl.pathname;
            }).map(async registration => {
              const succeeded = await registration.unregister();
              return succeeded === true && controlsThisApp;
            }));
            return retired.some(Boolean) ? controller : null;
          })();
          const retiredController = await Promise.race([cleanup, new Promise(resolve => {
            timer = setTimeout(() => resolve(null), 500);
          })]);
          // Unregistering does not detach a controller from this document. Only
          // a confirmed retirement may reload once to leave its cache-first
          // handler; a failed/timed-out cleanup must never cause a reload loop.
          if (retiredController) return retiredController;
        } finally {
          clearTimeout(timer);
        }
      }
    } catch (_) { /* Fingerprinted entrypoints also bypass an old worker cache. */ }
    // Flutter subsets icon fonts on each release but keeps their asset names.
    // Refresh only those small assets before engine initialization. Main code
    // and CanvasKit download in parallel with this bounded preparation.
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 4000);
      try {
        const assets = new URL('assets/', document.baseURI);
        const options = { cache: 'reload', signal: controller.signal };
        const response = await fetch(new URL('FontManifest.json', assets), options);
        if (!response.ok) throw new Error('Font manifest unavailable');
        const manifest = await response.json();
        if (!Array.isArray(manifest)) throw new Error('Invalid font manifest');
        const icons = new Set(['MaterialIcons', 'CupertinoIcons',
          'packages/cupertino_icons/CupertinoIcons']);
        const urls = new Set();
        for (const family of manifest) {
          if (!family || !icons.has(family.family) || !Array.isArray(family.fonts)) continue;
          for (const font of family.fonts) {
            if (!font || typeof font.asset !== 'string') continue;
            const url = new URL(encodeURI(font.asset), assets);
            if (url.origin === assets.origin && url.pathname.startsWith(assets.pathname)) {
              urls.add(url.href);
            }
          }
        }
        await Promise.allSettled([...urls].map(async url => {
          const font = await fetch(url, options);
          if (!font.ok) throw new Error('Icon font unavailable');
          await font.arrayBuffer();
        }));
      } finally {
        clearTimeout(timeout);
        controller.abort();
      }
    } catch (_) { /* The engine can retry normally, including offline caches. */ }
    return null;
  }

  let failureShown = false;
  function showStartupFailure() {
    if (failureShown) return;
    failureShown = true;
    const message = document.createElement('div');
    message.style.cssText = 'position:fixed;inset:0;display:grid;place-content:center;gap:16px;padding:24px;color:#fff;background:#101f22;font:16px sans-serif;text-align:center';
    const label = document.createElement('p');
    label.textContent = '스냅핏을 불러오지 못했어요. 인터넷 연결을 확인하고 다시 시도해주세요.';
    const retry = document.createElement('button');
    retry.textContent = '다시 불러오기';
    retry.onclick = () => location.reload();
    message.append(label, retry);
    document.body.append(message);
  }

  const assetsReady = prepareAssetCache();
  let reloadRequested = false;
  try {
    await _flutter.loader.load({
      onEntrypointLoaded: async (engineInitializer) => {
        try {
          const retiredController = await assetsReady;
          if (retiredController &&
              navigator.serviceWorker.controller === retiredController) {
            if (!reloadRequested) {
              reloadRequested = true;
              location.reload();
            }
            return;
          }
          const appRunner = await initializeWithInterfaceFonts(engineInitializer);
          await appRunner.runApp();
        } catch (_) {
          showStartupFailure();
        }
      },
    });
  } catch (_) {
    showStartupFailure();
  }
})();
"""


def entrypoint_history_for(output: Path) -> Path:
    # A local preview must not evict the production release's retained files.
    key = hashlib.sha256(str(output.resolve()).encode()).hexdigest()[:16]
    return ENTRYPOINT_HISTORY / key


def font_history_for(output: Path) -> Path:
    key = hashlib.sha256(str(output.resolve()).encode()).hexdigest()[:16]
    return FONT_HISTORY / key


def _verify_web_font(file: Path) -> None:
    match = FONT_PATTERN.fullmatch(file.name)
    if (not match or not file.is_file() or
            hashlib.sha256(file.read_bytes()).hexdigest()[:20] != match.group(1)):
        raise RuntimeError(f'Web font content hash mismatch: {file.name}')


def _read_font_releases(history: Path) -> list[list[str]]:
    record = history / 'releases.json'
    releases = json.loads(record.read_text()) if record.is_file() else []
    if (not isinstance(releases, list) or any(
            not isinstance(release, list) or not release or any(
                not isinstance(name, str) or not FONT_PATTERN.fullmatch(name)
                for name in release
            ) or release != sorted(set(release))
            for release in releases)):
        raise RuntimeError('Invalid web font release history')
    return releases


def _referenced_web_fonts(output: Path) -> list[str]:
    manifest = output / 'assets/FontManifest.json'
    if not manifest.is_file():
        return []
    names = set()
    for family in json.loads(manifest.read_text()):
        for font in family['fonts']:
            asset = font['asset']
            if not asset.startswith('web_fonts/'):
                continue
            name = asset.removeprefix('web_fonts/')
            if not FONT_PATTERN.fullmatch(name):
                raise RuntimeError(f'Unsafe web font path: {asset}')
            names.add(name)
    return sorted(names)


def preserve_web_fonts(output: Path, history: Path) -> None:
    """Remember the current manifest and archive immutable fonts before build."""
    history.mkdir(parents=True, exist_ok=True)
    for source in (output / 'assets').glob('StartupFontManifest.*.json'):
        match = STARTUP_MANIFEST_PATTERN.fullmatch(source.name)
        if not match or hashlib.sha256(source.read_bytes()).hexdigest()[:20] != match.group(1):
            raise RuntimeError('Startup font manifest content hash mismatch')
        shutil.copy2(source, history / source.name)
    folder = output / 'assets/web_fonts'
    for source in folder.glob('*'):
        if source.suffix not in FONT_SUFFIXES:
            continue
        _verify_web_font(source)
        shutil.copy2(source, history / source.name)
    current = _referenced_web_fonts(output)
    for name in current:
        _verify_web_font(folder / name)
    if not current:
        return
    releases = _read_font_releases(history)
    if releases and releases[-1] == current:
        return
    releases = [release for release in releases if release != current]
    releases.append(current)
    (history / 'releases.json').write_text(json.dumps(releases, indent=2) + '\n')
def restore_web_font_releases(
    output: Path,
    history: Path,
    generations: int = FONT_GENERATIONS,
) -> None:
    """Keep fonts used by the current and two previous distinct manifests.

    An open tab may retain its old FontManifest in Dart memory and load a font
    later for printing. HTTP revalidation alone cannot refresh that in-memory
    value, so immutable old font URLs must remain available across deployments.
    """
    releases = _read_font_releases(history)[-generations:]
    retained = {name for release in releases for name in release}
    for name in retained:
        _verify_web_font(history / name)
    folder = output / 'assets/web_fonts'
    if retained:
        folder.mkdir(parents=True, exist_ok=True)
    for name in retained:
        shutil.copy2(history / name, folder / name)
    for directory in (folder, history):
        for file in directory.glob('*'):
            if file.suffix in FONT_SUFFIXES and file.name not in retained:
                file.unlink()
    (history / 'releases.json').write_text(json.dumps(releases, indent=2) + '\n')
    startup_manifests = sorted(history.glob('StartupFontManifest.*.json'),
                               key=lambda item: item.stat().st_mtime)[-generations:]
    for source in startup_manifests:
        shutil.copy2(source, output / 'assets' / source.name)
    retained_manifests = {source.name for source in startup_manifests}
    for directory in (history, output / 'assets'):
        for source in directory.glob('StartupFontManifest.*.json'):
            if source.name not in retained_manifests:
                source.unlink()


def package_web_document_fonts(output: Path) -> dict:
    # Loading by an explicit sibling path supports both direct CLI execution
    # and the importlib test runner without relying on working-directory imports.
    spec = importlib.util.spec_from_file_location(
        'snapfit_web_font_pack', ROOT / 'tool/pack_web_fonts.py',
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    result = module.rewrite_web_font_manifest(output)
    (output / 'snapfit-web-font-pack.json').write_text(
        json.dumps(result, indent=2) + '\n',
    )
    return result


def package_startup_font_manifest(output: Path, *, root: Path = ROOT) -> str:
    """Keep the complete manifest for old tabs; opt only engine startup out.

    Dart's immutable declarations protect open tabs and document measurements.
    Fail this build on catalog drift rather than silently replacing a font.
    """
    path = output / 'assets/FontManifest.json'
    full = json.loads(path.read_text())
    declaration_source = (root / 'lib/core/fonts/document_font_manifest.dart').read_text()
    match = re.search(r"documentFontManifestJson = r'''(.*?)''';", declaration_source, re.S)
    if match is None:
        raise RuntimeError('Document font declarations are unavailable')
    declarations = json.loads(match.group(1))
    runtime = []
    for family in declarations:
        entry = json.loads(json.dumps(family))
        for font in entry['fonts']:
            source = root / font['asset']
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            font['asset'] = 'web_fonts/' + digest[:20] + source.suffix.lower()
        runtime.append(entry)
    actual = [family for family in full
              if any(font['asset'].startswith('web_fonts/')
                     for font in family['fonts'])]
    if actual != runtime:
        raise RuntimeError('Document font declarations differ from the Flutter build')
    # Verify the compiled dynamic loader uses the identical immutable font URLs.
    asset_source = (root / 'lib/core/fonts/document_font_assets.dart').read_text()
    asset_match = re.search(r"documentFontAssetPathsJson = r'''(.*?)''';", asset_source, re.S)
    if asset_match is None:
        raise RuntimeError('Immutable document font mappings are unavailable')
    mapping = json.loads(asset_match.group(1))
    expected = {source_font['asset']: font['asset']
                for source_family, family in zip(declarations, runtime)
                for source_font, font in zip(source_family['fonts'], family['fonts'])}
    if mapping != expected:
        raise RuntimeError('Immutable document font mappings differ from the Flutter build')
    registry_source = (root / 'lib/core/fonts/document_fonts.dart').read_text()
    registry_match = re.search(r'startupFamilies = \{(.*?)\};', registry_source, re.S)
    if (registry_match is None or
            set(re.findall(r"'([^']+)'", registry_match.group(1))) != STARTUP_FONT_FAMILIES):
        raise RuntimeError('Dart and engine startup font families differ')
    initial = [family for family in full
               if family['family'] in STARTUP_FONT_FAMILIES or
               all(not font['asset'].startswith('web_fonts/')
                   for font in family['fonts'])]
    if not {'NotoSans', 'Roboto', 'Poppins', 'Raleway'}.issubset(
            {family['family'] for family in initial}):
        raise RuntimeError('An interface font is missing from the startup manifest')
    data = (json.dumps(initial, ensure_ascii=False, separators=(',', ':')) + '\n').encode()
    name = 'StartupFontManifest.' + hashlib.sha256(data).hexdigest()[:20] + '.json'
    (output / 'assets' / name).write_bytes(data)
    return 'assets/' + name


def preserve_entrypoints(output: Path, history: Path) -> None:
    """Keep old immutable entrypoints available to tabs with cached HTML."""
    history.mkdir(parents=True, exist_ok=True)
    for source in output.glob('*.js'):
        match = ENTRYPOINT_PATTERN.fullmatch(source.name)
        if not match:
            continue
        expected = match.group(1) or match.group(2)
        if hashlib.sha256(source.read_bytes()).hexdigest()[:20] != expected:
            raise RuntimeError(f'Entrypoint content hash mismatch: {source.name}')
        shutil.copy2(source, history / source.name)


def restore_entrypoints(output: Path, history: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    for source in history.glob('*.js'):
        match = ENTRYPOINT_PATTERN.fullmatch(source.name)
        if not match:
            continue
        expected = match.group(1) or match.group(2)
        if hashlib.sha256(source.read_bytes()).hexdigest()[:20] != expected:
            raise RuntimeError(f'Cached entrypoint content hash mismatch: {source.name}')
        destination = output / source.name
        if not destination.exists():
            shutil.copy2(source, destination)


def record_entrypoint_release(
    output: Path,
    current: dict[str, str],
    history: Path,
    generations: int = ENTRYPOINT_GENERATIONS,
) -> None:
    """Retain the current release and two previous distinct release pairs."""
    record = history / 'releases.json'
    releases = json.loads(record.read_text()) if record.is_file() else []
    known = {item['bootstrap_file'] for item in releases}
    for bootstrap in sorted(history.glob('flutter_bootstrap.*.js'),
                            key=lambda item: item.stat().st_mtime):
        if bootstrap.name in known:
            continue
        main = re.search(r'"mainJsPath":"(main\.[0-9a-f]{20}\.dart\.js)"',
                         bootstrap.read_text())
        if main and (history / main.group(1)).is_file():
            releases.append({'main_file': main.group(1),
                             'bootstrap_file': bootstrap.name})
    pair = {key: current[key] for key in ('main_file', 'bootstrap_file')}
    releases = [item for item in releases if item != pair]
    releases.append(pair)
    releases = releases[-generations:]
    retained = {file for item in releases for file in item.values()}
    for folder in (history, output):
        for file in folder.glob('*.js'):
            if ENTRYPOINT_PATTERN.fullmatch(file.name) and file.name not in retained:
                file.unlink()
    record.write_text(json.dumps(releases, indent=2) + '\n')


def update_hosting_bootstrap_redirects(
    output: Path,
    bootstrap_name: str,
    config_path: Path = ROOT / 'firebase.json',
) -> None:
    """Cached HTML should load the latest startup code after every release."""
    if not config_path.is_file():
        return
    config = json.loads(config_path.read_text())
    hosting = config.get('hosting')
    if not isinstance(hosting, dict):
        return
    public = hosting.get('public')
    if not public or (config_path.parent / public).resolve() != output.resolve():
        return
    pattern = re.compile(r'^/flutter_bootstrap\.[0-9a-f]{20}\.js$')
    existing = hosting.get('redirects', [])
    sources = {'/' + file.name for file in output.glob('flutter_bootstrap.*.js')
               if pattern.fullmatch('/' + file.name)}
    sources.discard('/' + bootstrap_name)
    unrelated = [redirect for redirect in existing
                 if not pattern.fullmatch(redirect.get('source', ''))]
    hosting['redirects'] = unrelated + [
        {'source': source, 'destination': '/' + bootstrap_name, 'type': 302}
        for source in sorted(sources)
    ]
    config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + '\n')


def fingerprint_build(output: Path, startup_font_manifest: str | None = None) -> dict[str, str]:
    main = output / 'main.dart.js'
    bootstrap = output / 'flutter_bootstrap.js'
    index = output / 'index.html'
    main_hash = hashlib.sha256(main.read_bytes()).hexdigest()
    main_name = f'main.{main_hash[:20]}.dart.js'
    script = bootstrap.read_text(encoding='utf-8')
    marker = '"mainJsPath":"main.dart.js"'
    if script.count(marker) != 1 or script.count('_flutter.loader.load();') != 1:
        raise RuntimeError('Unexpected Flutter bootstrap; rebuild into a clean output directory.')
    script = script.replace(marker, f'"mainJsPath":"{main_name}"')
    script = script.replace('_flutter.loader.load();', STARTUP)
    script = script.replace(
        'const initialFontManifest = null; // SNAPFIT_ENGINE_FONT_MANIFEST',
        'const initialFontManifest = ' + json.dumps(startup_font_manifest) + ';',
    )
    bootstrap_hash = hashlib.sha256(script.encode()).hexdigest()
    bootstrap_name = f'flutter_bootstrap.{bootstrap_hash[:20]}.js'
    html = index.read_text(encoding='utf-8')
    if html.count('src="flutter_bootstrap.js"') != 1:
        raise RuntimeError('Unexpected Flutter HTML entrypoint.')
    if html.count('</head>') != 1:
        raise RuntimeError('Unexpected Flutter HTML head.')
    html = html.replace('src="flutter_bootstrap.js"', f'src="{bootstrap_name}"')
    # Discover the large, immutable entrypoint before bootstrap parsing and the
    # small icon-cache preparation. This uses the same URL as the loader so the
    # browser reuses the request, including on a cold connection.
    preloads = [
        f'  <link rel="preload" href="{main_name}" as="script" fetchpriority="high">',
    ]
    # Preload interface fonts only. Document originals remain byte-identical at
    # immutable URLs and are requested when the album renderer/editor needs them.
    if startup_font_manifest:
        initial = json.loads((output / startup_font_manifest).read_text())
        font_names = sorted({font['asset'].removeprefix('web_fonts/')
                             for family in initial for font in family['fonts']
                             if font['asset'].startswith('web_fonts/')})
    else:
        font_names = _referenced_web_fonts(output)
    for name in font_names:
        if name.endswith(('.ttf', '.otf')):
            preloads.append(
                f'  <link rel="preload" href="assets/web_fonts/{name}" '
                'as="fetch" crossorigin="anonymous" fetchpriority="low">',
            )
    html = html.replace('</head>', '\n'.join(preloads) + '\n</head>')
    shutil.copy2(main, output / main_name)
    (output / bootstrap_name).write_text(script, encoding='utf-8')
    index.write_text(html, encoding='utf-8')
    result = {'main_sha256': main_hash, 'main_file': main_name,
              'bootstrap_sha256': bootstrap_hash, 'bootstrap_file': bootstrap_name}
    (output / 'snapfit-web-build.json').write_text(json.dumps(result, indent=2))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/web')
    parser.add_argument('--existing-build', action='store_true',
                        help='Fingerprint a fresh, unmodified Flutter build without recompiling.')
    parser.add_argument('--target', type=Path, default=None,
                        help='Optional Dart entrypoint, for isolated quality fixtures.')
    parser.add_argument('--dart-define-from-file', type=Path, action='append', default=[],
                        help='Public client configuration JSON; never include server secrets.')
    args = parser.parse_args()
    output = args.output.resolve()
    history = entrypoint_history_for(output)
    font_history = font_history_for(output)
    preserve_entrypoints(output, history)
    preserve_web_fonts(output, font_history)
    if not args.existing_build:
        flutter = shutil.which('flutter')
        if flutter is None:
            fallback = Path.home() / 'flutter/bin/flutter'
            flutter = str(fallback) if fallback.is_file() else None
        if flutter is None:
            parser.error('Flutter SDK를 PATH에 등록해주세요.')
        command = [flutter, 'build', 'web', '--release', '--no-wasm-dry-run',
                   '--pwa-strategy=none',
                   '--dart-define=SNAPFIT_DEFER_DOCUMENT_FONTS=true',
                   f'--output={output}']
        if args.target:
            command.append(f'--target={args.target}')
        for source in args.dart_define_from_file:
            config_path = source.resolve()
            if not config_path.is_file():
                parser.error(f'웹 공개 설정 파일을 찾을 수 없습니다: {config_path}')
            command.append(f'--dart-define-from-file={config_path}')
        subprocess.run(command, cwd=ROOT, check=True)
    elif args.dart_define_from_file:
        parser.error('설정 변경은 새 빌드가 필요합니다. --existing-build와 함께 사용할 수 없습니다.')
    package_web_document_fonts(output)
    # A precompiled raw build has no Dart document-readiness gates. It must
    # retain the old eager engine policy rather than silently omitting fonts.
    startup_font_manifest = (None if args.existing_build
                             else package_startup_font_manifest(output))
    result = fingerprint_build(output, startup_font_manifest)
    preserve_entrypoints(output, history)
    record_entrypoint_release(output, result, history)
    restore_entrypoints(output, history)
    preserve_web_fonts(output, font_history)
    restore_web_font_releases(output, font_history)
    update_hosting_bootstrap_redirects(output, result['bootstrap_file'])
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
