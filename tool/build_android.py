#!/usr/bin/env python3
"""Build a compact verification APK without stale incremental ZIP free space.

Only generated APK/package state is removed. Dart compilation, web outputs,
source assets and all installed-app/user data stay outside this operation.
"""
from pathlib import Path
import argparse
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def reset_apk_package(root: Path, mode: str) -> None:
    if mode not in {'debug', 'profile', 'release'}:
        raise ValueError('Unsupported APK mode')
    root = root.resolve()
    paths = [
        root / 'build/app/intermediates/incremental' / ('package' + mode.title()),
        root / 'build/app/outputs/apk' / mode,
        root / 'build/app/outputs/flutter-apk' / f'app-{mode}.apk',
        root / 'build/app/outputs/flutter-apk' / f'app-{mode}.apk.sha1',
    ]
    for path in paths:
        parents = path.relative_to(root).parts
        current = root
        linked = False
        for part in parents:
            current = current / part
            linked = linked or current.is_symlink()
        if linked:
            raise RuntimeError(f'Refusing to remove linked package state: {path}')
    for path in paths:
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['debug', 'profile', 'release'], default='debug')
    parser.add_argument('--target-platform', default='android-arm64')
    args = parser.parse_args()
    flutter = shutil.which('flutter')
    if flutter is None:
        local = Path.home() / 'flutter/bin/flutter'
        flutter = str(local) if local.is_file() else None
    if flutter is None:
        parser.error('Flutter SDK not found')
    reset_apk_package(ROOT, args.mode)
    subprocess.run([flutter, 'build', 'apk', '--' + args.mode,
                    '--target-platform', args.target_platform], cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
