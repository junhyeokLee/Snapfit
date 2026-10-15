#!/usr/bin/env node
import { lstat, stat, readFile, realpath, access, mkdir, readdir, rm, writeFile } from 'node:fs/promises'
import { constants } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const packageDirectory = dirname(fileURLToPath(import.meta.url))
const runtimePins = JSON.parse(await readFile(join(packageDirectory, 'runtime-pins.json'), 'utf8'))
const failure = code => Object.assign(new Error(code), { code })
const safe = error => /^[a-z0-9_]{1,80}$/.test(error?.code ?? '') ? error.code : 'host_check_failed'
export function checkedPath(value) {
  // Paths become systemd fields/arguments. Exclude specifiers, quotes, spaces,
  // control characters and traversal instead of interpreting input as code.
  if (typeof value !== 'string' || !/^\/[A-Za-z0-9_./-]+$/.test(value) ||
      value.split('/').some((part, index) => index > 0 && (!part || part === '.' || part === '..'))) throw failure('invalid_host_path')
  return value
}
export function checkedUser(value) {
  if (typeof value !== 'string' || !/^[a-z_][a-z0-9_-]{0,31}$/.test(value) || value === 'root') throw failure('non_root_service_user_required')
  return value
}
export function secureEnvironmentMetadata(metadata) {
  if (!metadata.isFile() || metadata.isSymbolicLink?.() || (metadata.mode & 0o777) !== 0o600 || metadata.uid !== 0) throw failure('environment_file_requires_root_0600')
  // Never open, parse, source, print or copy the environment file.
}
export function assertEnvironmentOutsideProject(environmentFile, projectDir) {
  checkedPath(environmentFile); checkedPath(projectDir)
  if (environmentFile === projectDir || environmentFile.startsWith(`${projectDir}/`)) throw failure('environment_file_outside_project_required')
}
export function assertPinnedRuntime(nodeVersion, flutterVersion) {
  if (nodeVersion !== runtimePins.node.version) throw failure('pinned_node_version_required')
  if (flutterVersion?.frameworkVersion !== runtimePins.flutter.version ||
      flutterVersion?.frameworkRevision !== runtimePins.flutter.frameworkRevision ||
      flutterVersion?.dartSdkVersion !== runtimePins.flutter.dartVersion) throw failure('pinned_flutter_version_required')
}
export function renderService(template, values) {
  const replacements = {
    SERVICE_USER: checkedUser(values.serviceUser), SERVICE_GROUP: checkedUser(values.serviceGroup),
    PROJECT_DIR: checkedPath(values.projectDir), NODE_BIN: checkedPath(values.nodeBin), FLUTTER_BIN: checkedPath(values.flutterBin),
    FLUTTER_CACHE_DIR: checkedPath(values.flutterCacheDir), PUB_CACHE_DIR: checkedPath(values.pubCacheDir), ENV_FILE: checkedPath(values.environmentFile),
  }
  const unit = template.replace(/@([A-Z_]+)@/g, (_, key) => {
    if (!Object.hasOwn(replacements, key)) throw failure('unknown_service_placeholder')
    return replacements[key]
  })
  if (/@[A-Z_]+@/.test(unit)) throw failure('unresolved_service_placeholder')
  return unit
}
function parse(args) {
  const fields = { '--project-dir': 'projectDir', '--node-bin': 'nodeBin', '--flutter-bin': 'flutterBin',
    '--pub-cache-dir': 'pubCacheDir', '--service-user': 'serviceUser', '--service-group': 'serviceGroup', '--worker-env-path': 'environmentFile', '--render-unit': 'unitPath' }
  const config = { runtime: false }
  for (let index = 0; index < args.length; index++) {
    if (args[index] === '--runtime-check') { config.runtime = true; continue }
    if (args[index] === '--require-pinned-runtime') { config.requirePinnedRuntime = true; continue }
    if (args[index] === '--check-install') continue
    const field = fields[args[index]]
    if (!field || !args[index + 1] || Object.hasOwn(config, field)) throw failure('invalid_host_check_arguments')
    config[field] = args[++index]
  }
  for (const name of ['projectDir','nodeBin','flutterBin','pubCacheDir','environmentFile']) config[name] = checkedPath(config[name])
  config.serviceUser = checkedUser(config.serviceUser); config.serviceGroup = checkedUser(config.serviceGroup)
  if (config.unitPath) checkedPath(config.unitPath)
  return config
}
const processEnvironment = () => ({ PATH: '/usr/local/bin:/usr/bin:/bin' })
async function executable(path) { await access(path, constants.X_OK); return realpath(path) }
async function directory(path) { if (!(await stat(path)).isDirectory()) throw failure('host_directory_required') }

/** Metadata/version/cache checks only. Does not authenticate or call any API. */
export async function checkHost(config) {
  if (process.platform !== 'linux') throw failure('linux_systemd_host_required')
  const uid = Number(execFileSync('/usr/bin/id', ['-u', config.serviceUser], { env: processEnvironment(), encoding: 'utf8', stdio: ['ignore','pipe','ignore'] }).trim())
  if (!Number.isSafeInteger(uid) || uid === 0) throw failure('existing_non_root_service_user_required')
  execFileSync('/usr/bin/id', ['-g', config.serviceUser], { env: processEnvironment(), stdio: 'ignore' })
  const group = execFileSync('/usr/bin/getent', ['group', config.serviceGroup], { env: processEnvironment(), encoding: 'utf8', stdio: ['ignore','pipe','ignore'] }).trim().split(':')
  if (group[0] !== config.serviceGroup || !Number.isSafeInteger(Number(group[2])) || Number(group[2]) <= 0) throw failure('existing_non_root_service_group_required')
  const nodeBin = await executable(config.nodeBin), flutterBin = await executable(config.flutterBin)
  const nodeMajor = Number(execFileSync(nodeBin, ['-p', 'process.versions.node.split(".")[0]'], { env: processEnvironment(), encoding: 'utf8', stdio: ['ignore','pipe','ignore'] }).trim())
  if (!Number.isSafeInteger(nodeMajor) || nodeMajor < 22) throw failure('node_22_or_newer_required')
  const flutterRoot = dirname(dirname(flutterBin)), flutterCacheDir = join(flutterRoot, 'bin/cache')
  const version = JSON.parse(await readFile(join(flutterCacheDir, 'flutter.version.json'), 'utf8'))
  if (config.requirePinnedRuntime) {
    const nodeVersion = execFileSync(nodeBin, ['-p', 'process.versions.node'], { env: processEnvironment(), encoding: 'utf8', stdio: ['ignore','pipe','ignore'] }).trim()
    assertPinnedRuntime(nodeVersion, version)
  }
  const parts = /^([0-9]+)\.([0-9]+)/.exec(version.frameworkVersion ?? '')
  if (!parts || Number(parts[1]) < 3 || Number(parts[1]) === 3 && Number(parts[2]) < 44) throw failure('cached_flutter_3_44_or_newer_required')
  const engineDirectory = process.arch === 'x64' ? 'linux-x64' : process.arch === 'arm64' ? 'linux-arm64' : ''
  if (!engineDirectory) throw failure('supported_linux_architecture_required')
  await executable(join(flutterCacheDir, `artifacts/engine/${engineDirectory}/flutter_tester`))
  const projectDir = await realpath(config.projectDir), pubCacheDir = await realpath(config.pubCacheDir)
  for (const path of [projectDir, pubCacheDir, join(projectDir,'.dart_tool'), join(projectDir,'build')]) await directory(path)
  for (const path of ['pubspec.yaml','pubspec.lock','tool/print_fulfillment/run_worker.mjs','tool/print_fulfillment/render_paid_album_test.dart']) await access(join(projectDir,path), constants.R_OK)
  const dependencies = JSON.parse(await readFile(join(projectDir,'.dart_tool/package_config.json'), 'utf8'))
  if (!Array.isArray(dependencies.packages) || !dependencies.packages.length) throw failure('prepared_flutter_dependencies_required')
  const base = new URL(`file://${projectDir}/.dart_tool/package_config.json`)
  for (const dependency of dependencies.packages) {
    const root = new URL(dependency.rootUri, base)
    if (root.protocol !== 'file:') throw failure('local_flutter_dependencies_required')
    await directory(fileURLToPath(root))
  }
  assertEnvironmentOutsideProject(config.environmentFile, projectDir)
  if (!config.runtime) {
    secureEnvironmentMetadata(await lstat(config.environmentFile))
    const environmentPath = await realpath(config.environmentFile)
    assertEnvironmentOutsideProject(environmentPath, projectDir)
  }
  else {
    // systemd hides the already-validated secret file after reading it. The
    // service checks writable paths, never secret content or inherited credentials.
    for (const path of [pubCacheDir, flutterCacheDir, join(projectDir,'.dart_tool'), join(projectDir,'build')]) await access(path, constants.W_OK)
    const temp = '/var/lib/snapfit-print-worker/tmp'
    await mkdir(temp, { recursive: true, mode: 0o700 })
    const metadata = await lstat(temp)
    if (!metadata.isDirectory() || metadata.isSymbolicLink() || (metadata.mode & 0o777) !== 0o700 || metadata.uid !== process.getuid()) throw failure('worker_temp_requires_owner_0700')
    // The unit stops the whole process group. Remove only this worker's aborted
    // ephemeral folders before its next start, without opening their files.
    for (const entry of await readdir(temp, { withFileTypes: true })) {
      if (entry.isDirectory() && /^snapfit-print-(?:fixture-)?[A-Za-z0-9]+$/.test(entry.name)) await rm(join(temp,entry.name), { recursive: true, force: true })
    }
  }
  return { ...config, projectDir, nodeBin, flutterBin, flutterCacheDir, pubCacheDir }
}
async function main() {
  const config = await checkHost(parse(process.argv.slice(2)))
  if (config.unitPath) {
    const template = await readFile(join(packageDirectory,'snapfit-print-worker.service.in'), 'utf8')
    await writeFile(config.unitPath, renderService(template,config), { mode: 0o600, flag: 'wx' })
  }
  process.stdout.write(JSON.stringify({ checked: true, credentialsRead: false, providerRequests: 0, serviceStarted: false }) + '\n')
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => { process.stderr.write(JSON.stringify({ error: safe(error) }) + '\n'); process.exitCode = 78 })
}
