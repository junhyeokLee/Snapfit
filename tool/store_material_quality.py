#!/usr/bin/env python3
"""Run local CI parity gates with captured exits, logs and generated hashes."""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--flutter', default='flutter')
a = p.parse_args()
flutter = shutil.which(a.flutter) or a.flutter
dart = str(pathlib.Path(flutter).parent / 'dart') if '/' in flutter else 'dart'
out = ROOT / 'build/store_material_harness/quality'
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ)
env['PATH'] = str(pathlib.Path(flutter).parent) + os.pathsep + env.get('PATH', '')

def generated():
    return {str(f.relative_to(ROOT)): hashlib.sha256(f.read_bytes()).hexdigest()
            for f in (ROOT / 'lib').rglob('*.dart')
            if f.name.endswith(('.g.dart', '.freezed.dart'))}

before = generated()
commands = [
    ('generated', [dart, 'run', 'build_runner', 'build', '--delete-conflicting-outputs']),
    ('format', [dart, 'format', '--output=none', '--set-exit-if-changed', 'lib', 'test']),
    ('analyze', [flutter, 'analyze']),
    ('supabase-readiness', [sys.executable, 'tool/supabase_readiness_check.py', '--skip-remote']),
    ('template-quality', [sys.executable, 'tool/template_quality_check.py']),
    ('diff-check', ['git', 'diff', '--check']),
]
results = []
for name, command in commands:
    with (out / (name + '.log')).open('w') as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    results.append({'gate': name, 'command': command, 'exit_code': result.returncode})
    print(name, result.returncode, flush=True)
after = generated()
changed = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
results.append({'gate': 'generated-parity', 'exit_code': int(bool(changed)), 'changed': changed})
(out / 'report.json').write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))
sys.exit(int(any(item['exit_code'] != 0 for item in results)))
