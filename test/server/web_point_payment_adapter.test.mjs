import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

test('actual compiled web adapter fences a hung SDK before any new invoice and releases only its physical operation', {timeout: 120_000}, () => {
  const directory = mkdtempSync(join(tmpdir(), 'snapfit-web-point-adapter-'));
  try {
    const root = fileURLToPath(new URL('../..', import.meta.url));
    const harness = join(root, 'test/support/web_point_payment_adapter_harness.dart');
    const compiled = join(directory, 'adapter.js');
    execFileSync(process.env.DART_BIN ?? 'dart', ['compile', 'js', harness, '-o', compiled],
      {cwd: root, timeout: 90_000, stdio: 'pipe'});
    const browser = join(directory, 'browser.cjs');
    writeFileSync(browser, `
      globalThis.self = globalThis;
      globalThis.window = globalThis;
      Object.defineProperty(globalThis, 'navigator', {value: {userAgent:'SnapFit Desktop Node Fixture'}, configurable:true});
      const windows = new Map();
      globalThis.pointAdapterFixture = {count:0,lastPayment:'',settle(id,error){
        const window = windows.get(id); if(!window) throw new Error('SDK window missing');
        if(error) window.reject(new Error('late provider failure')); else window.resolve(null);
      }};
      globalThis.PortOne = {requestPayment(request){
        pointAdapterFixture.count++; pointAdapterFixture.lastPayment=request.paymentId;
        return new Promise((resolve,reject)=>windows.set(request.paymentId,{resolve,reject}));
      }};
      globalThis.fetch = () => {throw new Error('No provider, payment, network or production call is allowed');};
    `);
    const output = execFileSync(process.execPath, ['--require', browser, compiled],
      {cwd: root, timeout: 20_000, encoding: 'utf8', stdio: 'pipe'});
    assert.match(output, /web-point-adapter: verified real JS guard/);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});
