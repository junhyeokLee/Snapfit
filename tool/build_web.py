#!/usr/bin/env python3
"""Build the existing Flutter app with content-addressed browser entrypoints.

Old Flutter service workers can otherwise serve an obsolete main.dart.js even
after a reload. No login storage, cookies, albums or user files are removed.
"""
from __future__ import annotations

import argparse
import hashlib
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
STARTUP = r"""
(async () => {
  // Retire only this app's generated Flutter worker. Other worker scopes and
  // all authentication/document storage remain intact.
  try {
    if ('serviceWorker' in navigator) {
      const base = new URL('.', document.baseURI);
      const workerUrl = new URL('flutter_service_worker.js', base);
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.filter(registration => {
        const worker = registration.active || registration.waiting || registration.installing;
        if (!worker || registration.scope !== base.href) return false;
        const url = new URL(worker.scriptURL);
        return url.origin === workerUrl.origin && url.pathname === workerUrl.pathname;
      }).map(registration => registration.unregister()));
    }
  } catch (_) { /* Fingerprinted entrypoints also bypass an old worker cache. */ }
  // Flutter subsets icon fonts on each release but keeps their asset names.
  // Refresh only those small assets before the engine can read an older HTTP
  // cache entry. Consume each body so the refreshed bytes are ready to reuse.
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
  try {
    await _flutter.loader.load();
  } catch (_) {
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
})();
"""


def entrypoint_history_for(output: Path) -> Path:
    # A local preview must not evict the production release's retained files.
    key = hashlib.sha256(str(output.resolve()).encode()).hexdigest()[:16]
    return ENTRYPOINT_HISTORY / key


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


def fingerprint_build(output: Path) -> dict[str, str]:
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
    bootstrap_hash = hashlib.sha256(script.encode()).hexdigest()
    bootstrap_name = f'flutter_bootstrap.{bootstrap_hash[:20]}.js'
    html = index.read_text(encoding='utf-8')
    if html.count('src="flutter_bootstrap.js"') != 1:
        raise RuntimeError('Unexpected Flutter HTML entrypoint.')
    shutil.copy2(main, output / main_name)
    (output / bootstrap_name).write_text(script, encoding='utf-8')
    index.write_text(html.replace('src="flutter_bootstrap.js"',
                                 f'src="{bootstrap_name}"'), encoding='utf-8')
    result = {'main_sha256': main_hash, 'main_file': main_name,
              'bootstrap_sha256': bootstrap_hash, 'bootstrap_file': bootstrap_name}
    (output / 'snapfit-web-build.json').write_text(json.dumps(result, indent=2))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/web')
    parser.add_argument('--existing-build', action='store_true',
                        help='Fingerprint a fresh, unmodified Flutter build without recompiling.')
    parser.add_argument('--dart-define-from-file', type=Path, action='append', default=[],
                        help='Public client configuration JSON; never include server secrets.')
    args = parser.parse_args()
    output = args.output.resolve()
    history = entrypoint_history_for(output)
    preserve_entrypoints(output, history)
    if not args.existing_build:
        flutter = shutil.which('flutter')
        if flutter is None:
            fallback = Path.home() / 'flutter/bin/flutter'
            flutter = str(fallback) if fallback.is_file() else None
        if flutter is None:
            parser.error('Flutter SDK를 PATH에 등록해주세요.')
        command = [flutter, 'build', 'web', '--release', '--no-wasm-dry-run',
                   '--pwa-strategy=none', f'--output={output}']
        for source in args.dart_define_from_file:
            config_path = source.resolve()
            if not config_path.is_file():
                parser.error(f'웹 공개 설정 파일을 찾을 수 없습니다: {config_path}')
            command.append(f'--dart-define-from-file={config_path}')
        subprocess.run(command, cwd=ROOT, check=True)
    elif args.dart_define_from_file:
        parser.error('설정 변경은 새 빌드가 필요합니다. --existing-build와 함께 사용할 수 없습니다.')
    result = fingerprint_build(output)
    preserve_entrypoints(output, history)
    record_entrypoint_release(output, result, history)
    restore_entrypoints(output, history)
    update_hosting_bootstrap_redirects(output, result['bootstrap_file'])
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
