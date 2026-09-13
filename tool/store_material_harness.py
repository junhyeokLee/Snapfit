#!/usr/bin/env python3
"""Deterministic store/material regression gate; no device FPS claims."""
import argparse
import json
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--phase', default='baseline')
p.add_argument('--test', action='append')
p.add_argument('--full', action='store_true', help='Run the complete Flutter test suite')
p.add_argument('--flutter', default='flutter', help='Flutter executable (absolute path for service runners)')
a = p.parse_args()
out = ROOT / 'build/store_material_harness' / a.phase
out.mkdir(parents=True, exist_ok=True)
tests = a.test or [
    'test/widget/published_store_catalog_test.dart',
    'test/widget/catalog_favorites_test.dart',
    'test/widget/editor_point_shop_gate_test.dart',
    'test/widget/studio_decorations_test.dart',
    'test/widget/premium_template_list_test.dart',
    'test/widget/point_shop_purchase_flow_test.dart',
    'test/widget/template_point_shop_access_test.dart',
    'test/unit/catalog_favorites_test.dart',
]
if not a.test:
    tests += [str(f.relative_to(ROOT)) for f in sorted((ROOT / 'test/optimization').glob('*_test.dart'))]
if a.full:
    tests = []
cmd = [a.flutter, 'test', '--reporter', 'json', *tests]
start = time.monotonic()
with (out / 'events.jsonl').open('w') as log:
    try:
        result = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    except OSError as error:
        log.write(str(error))
        result = subprocess.CompletedProcess(cmd, 127)
events = []
for line in (out / 'events.jsonl').read_text().splitlines():
    try:
        events.append(json.loads(line))
    except ValueError:
        pass
report = {
    'phase': a.phase, 'command': cmd, 'exit_code': result.returncode,
    'elapsed_seconds': time.monotonic() - start,
    'tests_passed': sum(e.get('type') == 'testDone' and e.get('result') == 'success' and not e.get('hidden', False) and not e.get('skipped', False) for e in events),
    'errors': [e for e in events if e.get('type') == 'error'],
    'metrics': [e['message'] for e in events if e.get('type') == 'print' and e.get('message', '').startswith('BUDGET ')],
    'device_profile': 'not measured; deterministic work budgets are not FPS',
    'git_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
}
(out / 'report.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
sys.exit(result.returncode)
