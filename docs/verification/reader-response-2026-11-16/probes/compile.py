from pathlib import Path
import subprocess,sys
p=Path(__file__).parent;r=Path('/Users/devsheep/SnapFit/SnapFit');c=Path('/Users/devsheep/flutter/bin/cache')
cmd=[str(c/'dart-sdk/bin/dartaotruntime'),str(c/'artifacts/engine/darwin-x64/frontend_server_aot.dart.snapshot'),'--sdk-root='+str(c/'artifacts/engine/common/flutter_patched_sdk')+'/','--target=flutter','--packages='+str(r/'.dart_tool/package_config.json'),'--output-dill='+str(p/'audit.dill'),str(p/'runner.dart')]
with (p/'compile.log').open('w') as f: result=subprocess.run(cmd,cwd=r,stdout=f,stderr=subprocess.STDOUT,timeout=150)
lines=(p/'compile.log').read_text().splitlines();print('\n'.join(lines[-4:]));print('compiler exit',result.returncode,flush=True)
if result.returncode or not lines[-1].endswith(' 0'):sys.exit(1)
