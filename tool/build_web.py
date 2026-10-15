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
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
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
    print(json.dumps(fingerprint_build(output), indent=2))


if __name__ == '__main__':
    main()
