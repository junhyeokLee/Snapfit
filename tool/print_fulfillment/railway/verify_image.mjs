import { readFile, access, mkdir, rm, writeFile } from 'node:fs/promises'
import { constants } from 'node:fs'
import { resolve, join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { renderPaidAlbum } from '../run_worker.mjs'

const project = resolve(dirname(fileURLToPath(import.meta.url)), '../../..')
const error = code => Object.assign(new Error(code), { code })
export function checkedRuntime(pins, version, flutter, platform = process.platform, arch = process.arch) {
  if (platform !== 'linux' || arch !== 'x64' || pins.platform !== 'linux-x64') throw error('linux_x64_runtime_required')
  if (version !== pins.node.version || flutter.frameworkVersion !== pins.flutter.version ||
      flutter.frameworkRevision !== pins.flutter.frameworkRevision || flutter.dartSdkVersion !== pins.flutter.dartVersion) {
    throw error('pinned_runtime_required')
  }
}
export function checkedFixtureSummary(scenario, rendered, elapsedMs) {
  const pageCount = scenario === 'HARD_80' ? 80 : scenario === 'SOFT_20' ? 20 : 0
  if (!pageCount || rendered?.manifest?.pageCount !== pageCount || rendered.manifest.missingAssets?.length ||
      rendered.manifest.renderer !== 'flutter-layer-builder-raster-v1' ||
      !rendered.cover?.length || !rendered.interior?.length ||
      rendered.cover.subarray(0, 5).toString() !== '%PDF-' || rendered.interior.subarray(0, 5).toString() !== '%PDF-') {
    throw error('fixture_validation_failed')
  }
  return { scenario, elapsedMs, coverBytes: rendered.cover.length, interiorBytes: rendered.interior.length }
}
async function main() {
  const args = process.argv.slice(2)
  if (args.length > 1 || args.length === 1 && args[0] !== '--build-fixtures') throw error('image_check_arguments_invalid')
  const pins = JSON.parse(await readFile(join(project, 'tool/print_fulfillment/linux/runtime-pins.json'), 'utf8'))
  const flutter = JSON.parse(await readFile('/opt/flutter/bin/cache/flutter.version.json', 'utf8'))
  checkedRuntime(pins, process.versions.node, flutter)
  if (process.getuid?.() === 0) throw error('non_root_worker_required')
  if (args.length) await mkdir(join(project, 'build'), { recursive: true, mode: 0o700 })
  for (const path of ['/opt/flutter/bin/cache', process.env.PUB_CACHE, join(project, '.dart_tool'), join(project, 'build')]) {
    if (!path) throw error('worker_cache_required')
    await access(path, constants.W_OK)
  }
  const temp = process.env.TMPDIR
  if (temp !== '/tmp/snapfit-print-worker') throw error('worker_temp_required')
  await mkdir(temp, { recursive: true, mode: 0o700 })
  const evidencePath = join(project, 'build/print-worker-image-check.json')
  if (!args.length) {
    const evidence = JSON.parse(await readFile(evidencePath, 'utf8'))
    if (evidence.fixtureOnly !== true || evidence.node !== pins.node.version || evidence.flutter !== pins.flutter.version ||
        !['SOFT_20', 'HARD_80'].every(scenario => evidence.scenarios?.some(v => v.scenario === scenario && v.coverBytes > 0 && v.interiorBytes > 0))) {
      throw error('image_fixture_validation_required')
    }
    process.stdout.write(JSON.stringify({ runtimeChecked: true, fixtureBuildChecked: true, productionApproved: false }) + '\n')
    return
  }
  const scenarios = []
  for (const scenario of ['SOFT_20', 'HARD_80']) {
    let rendered
    try {
      const started = Date.now()
      rendered = await renderPaidAlbum(null, { fixture: true, fixtureScenario: scenario })
      scenarios.push(checkedFixtureSummary(scenario, rendered, Date.now() - started))
    } finally { if (rendered?.directory) await rm(rendered.directory, { recursive: true, force: true }) }
  }
  const evidence = { fixtureOnly: true, supplierCalls: 0, productionApproved: false, node: pins.node.version, flutter: pins.flutter.version, scenarios }
  await writeFile(evidencePath, JSON.stringify(evidence), { mode: 0o600 })
  process.stdout.write(JSON.stringify(evidence) + '\n')
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(cause => { process.stderr.write(JSON.stringify({ error: /^[a-z0-9_]{1,80}$/.test(cause?.code ?? '') ? cause.code : 'image_runtime_check_failed' }) + '\n'); process.exitCode = 1 })
}
