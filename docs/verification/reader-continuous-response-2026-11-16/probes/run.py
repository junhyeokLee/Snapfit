from pathlib import Path
import os,sys,subprocess
r=Path('/Users/devsheep/SnapFit/SnapFit');t=Path('/tmp/snapfit-reader-repeat-20261116');suite=sys.argv[1];pattern=sys.argv[2] if len(sys.argv)>2 else '.*'
env=dict(os.environ,FLUTTER_TEST='true',AUDIT_SUITE=suite,AUDIT_ASSETS=str(t/'assets'),NEXT_AUDIT_DIR=str(t/'screens'),SNAPFIT_CAPTURE_SAVED_ALBUM=str(t/'screens'),SNAPFIT_TEST_FILTER=pattern)
cmd=['/Users/devsheep/flutter/bin/cache/artifacts/engine/darwin-x64/flutter_tester','--disable-vm-service','--run-forever','--enable-software-rendering','--skia-deterministic-rendering','--non-interactive','--use-test-fonts','--disable-asset-fonts','--packages='+str(r/'.dart_tool/package_config.json'),'--flutter-assets-dir='+str(t/'assets'),str(t/'audit.dill')]
try:
 with (t/(suite+'.log')).open('w') as f:result=subprocess.run(cmd,env=env,cwd=r,stdout=f,stderr=subprocess.STDOUT,timeout=300 if suite == 'paper_motion' else 120)
 print(suite,'exit',result.returncode);print('\n'.join((t/(suite+'.log')).read_text().splitlines()[-7:]));sys.exit(result.returncode)
except subprocess.TimeoutExpired:print(suite,'TIMEOUT');sys.exit(124)
