import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFile } from 'node:fs/promises'
import { execFileSync, spawnSync } from 'node:child_process'
import { checkedPath, checkedUser, secureEnvironmentMetadata, assertEnvironmentOutsideProject, assertPinnedRuntime, renderService } from '../../tool/print_fulfillment/linux/check-linux-host.mjs'

const directory = new URL('../../tool/print_fulfillment/linux/', import.meta.url)
const template = await readFile(new URL('snapfit-print-worker.service.in', directory), 'utf8')
const pins = JSON.parse(await readFile(new URL('runtime-pins.json', directory), 'utf8'))
const values = { serviceUser: 'snapfit-worker', serviceGroup: 'snapfit-worker', projectDir: '/opt/snapfit/app',
  nodeBin: '/opt/node/bin/node', flutterBin: '/opt/flutter/bin/flutter', flutterCacheDir: '/opt/flutter/bin/cache',
  pubCacheDir: '/var/cache/snapfit-pub', environmentFile: '/etc/snapfit-print/worker.env' }

test('rendered service pins runner directory and restarts process failure without launching a one-shot job', () => {
  const service = renderService(template, values)
  assert.match(service, /^Type=exec$/m)
  assert.match(service, /^WorkingDirectory=\/opt\/snapfit\/app$/m)
  assert.match(service, /^ExecStart=\/opt\/node\/bin\/node -- \/opt\/snapfit\/app\/tool\/print_fulfillment\/run_worker\.mjs$/m)
  assert.match(service, /^Restart=always$/m)
  assert.match(service, /^RestartSec=30$/m)
  assert.match(service, /^KillMode=control-group$/m)
  assert.match(service, /^TimeoutStopSec=30$/m)
  assert.match(service, /^OOMPolicy=stop$/m)
  assert.match(service, /^Environment=HOME=\/var\/lib\/snapfit-print-worker$/m)
  assert.match(service, /--runtime-check --require-pinned-runtime/)
  assert.doesNotMatch(service, /--once|--fixture|@[A-Z_]+@/)
})

test('service has private temp/state permissions and secret file is excluded from its filesystem view', () => {
  const service = renderService(template, values)
  for (const setting of ['UMask=0077', 'StateDirectoryMode=0700', 'RuntimeDirectoryMode=0700', 'NoNewPrivileges=true',
    'PrivateTmp=true', 'ProtectSystem=strict', 'ProtectHome=read-only', 'InaccessiblePaths=/etc/snapfit-print/worker.env']) assert.ok(service.includes(setting))
  assert.match(service, /^EnvironmentFile=\/etc\/snapfit-print\/worker\.env$/m)
  assert.match(service, /^StandardOutput=journal$/m)
  assert.match(service, /^StandardError=journal$/m)
  assert.doesNotMatch(service, /PASSWORD=|JWT=|V2_API_SECRET=|SERVICE_ROLE_KEY=|PRODUCTION_API_KEY=/)
})

test('public install paths cannot inject commands, systemd specifiers or another directive', () => {
  for (const path of ['/tmp/app\nExecStart=/bin/sh', '/tmp/$(private)', '/tmp/%i', '/tmp/"secret"', '/tmp/../secret',
    '/tmp//secret', '/tmp/space here', 'relative/path']) assert.throws(() => checkedPath(path), /invalid_host_path/)
  for (const user of ['root', 'someone\nGroup=root', 'worker;echo', '']) assert.throws(() => checkedUser(user), /non_root_service_user_required/)
  assert.equal(checkedPath('/opt/snapfit/app'), '/opt/snapfit/app')
})

test('environment-file policy uses only root/file/mode metadata, never secret contents', () => {
  const metadata = Object.defineProperty({ mode: 0o100600, uid: 0, isFile: () => true, isSymbolicLink: () => false },
    'contents', { get() { assert.fail('Secret contents were inspected') }, enumerable: false })
  assert.doesNotThrow(() => secureEnvironmentMetadata(metadata))
  for (const changes of [{ mode: 0o100644 }, { uid: 1000 }, { isSymbolicLink: () => true }, { isFile: () => false }]) {
    assert.throws(() => secureEnvironmentMetadata({ ...metadata, ...changes }), /environment_file_requires_root_0600/)
  }
})

test('credentials cannot reside within the project; neighboring directories remain valid', () => {
  for (const environmentFile of ['/opt/snapfit/app', '/opt/snapfit/app/worker.env', '/opt/snapfit/app/.secrets/worker.env']) {
    assert.throws(() => assertEnvironmentOutsideProject(environmentFile, '/opt/snapfit/app'), /environment_file_outside_project_required/)
  }
  for (const environmentFile of ['/etc/snapfit-print/worker.env', '/opt/snapfit/app-config/worker.env']) {
    assert.doesNotThrow(() => assertEnvironmentOutsideProject(environmentFile, '/opt/snapfit/app'))
  }
})

test('installer syntax is valid and installation never starts/enables a service or creates accounts', async () => {
  const file = new URL('install-linux-service.sh', directory)
  assert.equal(execFileSync('/bin/bash', ['-n', file.pathname], { encoding: 'utf8', env: { PATH: '/usr/bin:/bin' } }), '')
  const script = await readFile(file, 'utf8')
  assert.doesNotMatch(script, /systemctl (?:start|enable|restart)|useradd|adduser|set -x|source\s|\beval\s/)
  assert.match(script, /systemd-analyze verify/)
  assert.match(script, /systemctl daemon-reload/)
  assert.match(script, /existing_unit_requires_explicit_replace/)
})

test('configuration check has no API, commerce, secret printing or SDK download path', async () => {
  const source = await readFile(new URL('check-linux-host.mjs', directory), 'utf8')
  assert.doesNotMatch(source, /fetch\(|https:\/\/|curl\s|wget\s|process\.env|readFile\(config\.environmentFile/)
  const example = await readFile(new URL('worker.env.example', directory), 'utf8')
  const assignments = example.split('\n').filter(line => /^[A-Z_]+=/.test(line))
  assert.equal(assignments.length, 4)
  assert.ok(assignments.every(line => line.split('=')[1].startsWith('REPLACE_')))
})

test('non-Linux configuration probe stops before filesystem installation or credential access', { skip: process.platform === 'linux' }, () => {
  const probe = spawnSync(process.execPath, ['--', new URL('check-linux-host.mjs', directory).pathname,
    '--check-install', '--project-dir', values.projectDir, '--node-bin', values.nodeBin,
    '--flutter-bin', values.flutterBin, '--pub-cache-dir', values.pubCacheDir,
    '--service-user', values.serviceUser, '--service-group', values.serviceGroup,
    '--worker-env-path', values.environmentFile], { encoding: 'utf8', env: { PATH: '/usr/bin:/bin' } })
  assert.equal(probe.status, 78)
  assert.equal(probe.stdout, '')
  assert.deepEqual(JSON.parse(probe.stderr), { error: 'linux_systemd_host_required' })
})

test('host arguments never use Node own environment-file option and retain a Node script boundary', async () => {
  const checker = await readFile(new URL('check-linux-host.mjs', directory), 'utf8')
  const installer = await readFile(new URL('install-linux-service.sh', directory), 'utf8')
  assert.doesNotMatch(checker + installer + template, /--env-file\b/)
  assert.match(installer, /"\$worker_node_bin" -- "\$worker_package_dir\/check-linux-host\.mjs"/)
  assert.match(template, /^ExecStartPre=@NODE_BIN@ -- /m)
  assert.match(template, /--worker-env-path @ENV_FILE@/)
})

test('production host pins require the exact tested Flutter revision and Dart runtime', () => {
  const version = { frameworkVersion: pins.flutter.version, frameworkRevision: pins.flutter.frameworkRevision, dartSdkVersion: pins.flutter.dartVersion }
  assert.doesNotThrow(() => assertPinnedRuntime(pins.node.version, version))
  for (const value of ['22.0.0', '24.20.0', '24.22.0', `v${pins.node.version}`]) {
    assert.throws(() => assertPinnedRuntime(value, version), /pinned_node_version_required/)
  }
  for (const change of [{ frameworkVersion: '3.47.2' }, { frameworkRevision: 'unapproved_revision' }, { dartSdkVersion: '3.13.2' }]) {
    assert.throws(() => assertPinnedRuntime(pins.node.version, { ...version, ...change }), /pinned_flutter_version_required/)
  }
})

test('runtime downloads use one fixed official Linux archive with a checksum, never a floating release', () => {
  assert.equal(pins.platform, 'linux-x64')
  assert.equal(pins.node.url, `https://nodejs.org/dist/v${pins.node.version}/node-v${pins.node.version}-linux-x64.tar.xz`)
  assert.equal(pins.flutter.url, `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${pins.flutter.version}-stable.tar.xz`)
  assert.match(pins.node.sha256, /^[a-f0-9]{64}$/)
  assert.match(pins.flutter.sha256, /^[a-f0-9]{64}$/)
  assert.match(pins.flutter.frameworkRevision, /^[a-f0-9]{40}$/)
  assert.equal(pins.notes.linuxRuntimeVerified, false)
  assert.equal(pins.notes.physicalSampleApproved, false)
  assert.ok(pins.ubuntu.packages.includes('libglu1-mesa'))
  assert.ok(pins.ubuntu.packages.includes('libfontconfig1'))
  assert.doesNotMatch(pins.node.url + pins.flutter.url, /latest/)
  assert.doesNotMatch(JSON.stringify(pins.ubuntu.packages), /xvfb|android-sdk|chromium/)
})
