import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createRequire } from 'node:module'
import { pathToFileURL } from 'node:url'
import { resolve } from 'node:path'
import { test } from 'node:test'

const directory = new URL('../../tool/print_fulfillment/railway/', import.meta.url)
const packageFile = new URL('package.json', directory)
const packageDefinition = JSON.parse(await readFile(packageFile, 'utf8'))
const pins = JSON.parse(await readFile(new URL('../linux/runtime-pins.json', directory), 'utf8'))
// npm ci in the deployment-tool directory is the normal route. CI/local review
// may use an isolated, pinned toolchain without adding node_modules to the app.
const moduleRoot = process.env.SNAPFIT_RAILWAY_TEST_TOOLCHAIN
  ? pathToFileURL(resolve(process.env.SNAPFIT_RAILWAY_TEST_TOOLCHAIN, 'package.json'))
  : packageFile
const require = createRequire(moduleRoot)
const sdkUrl = pathToFileURL(require.resolve('railway/iac'))
const sdkPackage = JSON.parse(await readFile(new URL('../../package.json', sdkUrl), 'utf8'))
const sdk = await import(sdkUrl.href)
const source = await readFile(new URL('.railway/railway.ts', directory), 'utf8')
assert.equal((source.match(/from ['"]railway\/iac['"]/g) ?? []).length, 1)
const executableSource = source.replace(/(['"])railway\/iac\1/, JSON.stringify(sdkUrl.href))
const configuration = await import(`data:text/javascript;base64,${Buffer.from(executableSource).toString('base64')}`)
const evaluate = environment => configuration.default(sdk.createRailwayContext({
  command: 'plan', environment, projectName: 'snapfit-print',
}))

test('the real pinned SDK produces one locally sourced worker with no extra billed resources', () => {
  assert.equal(sdkPackage.version, '3.16.0')
  const project = evaluate('production')
  assert.equal(project.name, 'snapfit-print')
  assert.equal(project.resources.length, 1)
  const worker = project.resources[0]
  assert.equal(worker.type, 'service')
  assert.equal(worker.kind, 'empty')
  assert.equal(worker.name, 'snapfit-print-worker')
  assert.equal(worker.source, undefined)
  assert.equal(worker.networking, undefined)
  assert.equal(worker.volumeMounts, undefined)
  assert.equal(worker.volumeAttachments, undefined)
  assert.deepEqual(sdk.validateGraph({ version: sdk.RAILWAY_GRAPH_VERSION,
    resources: project.resources, edges: [] }), [])
})

test('SDK normalization keeps sleeping disabled, one replica and shutdown overlap at zero', () => {
  const { deploy } = evaluate('production').resources[0]
  assert.equal(deploy.numReplicas, 1)
  assert.equal(deploy.multiRegionConfig, undefined)
  assert.equal(deploy.region, 'asia-southeast1-eqsg3a')
  assert.equal(deploy.sleepApplication, false)
  assert.equal(deploy.restartPolicyType, 'ALWAYS')
  assert.equal(deploy.cronSchedule, undefined)
  assert.equal(deploy.overlapSeconds, 0)
  assert.equal(deploy.drainingSeconds, 30)
  assert.equal(deploy.restartPolicyMaxRetries, undefined)
})

test('one worker uses supported CPU and byte-memory caps with the declared Dockerfile', () => {
  const { build, deploy } = evaluate('production').resources[0]
  assert.deepEqual(build, { builder: 'DOCKERFILE', dockerfilePath: 'Dockerfile' })
  assert.deepEqual(deploy.limitOverride, { containers: { cpu: 2, memoryBytes: 4294967296 } })
  assert.equal(deploy.resourceLimits, undefined)
  assert.equal(deploy.cpuLimit, undefined)
  assert.equal(deploy.memoryLimit, undefined)
})

test('evaluating the preparation config neither reads credentials nor changes an external service', () => {
  assert.doesNotMatch(source, /process\.env|fetch\s*\(|readFile|execFile|spawn\s*\(|https:\/\//)
  const previousFetch = globalThis.fetch
  globalThis.fetch = () => { assert.fail('Offline configuration attempted a network request') }
  try {
    const worker = evaluate('production').resources[0]
    assert.equal(worker.variables, undefined)
    // SDK env is a non-enumerable reference accessor, not literal credentials.
    assert.equal(Object.keys(worker).includes('env'), false)
    assert.equal(worker.deploy.preDeployCommand, undefined)
    assert.equal(worker.deploy.registryCredentials, undefined)
    assert.deepEqual(JSON.parse(JSON.stringify(evaluate('development'))),
      JSON.parse(JSON.stringify(evaluate('production'))))
  } finally { globalThis.fetch = previousFetch }
})

test('deployment tools are reproducibly locked and share the host runtime pin', async () => {
  const lock = JSON.parse(await readFile(new URL('package-lock.json', directory), 'utf8'))
  assert.equal(packageDefinition.private, true)
  assert.deepEqual(packageDefinition.dependencies, { '@railway/cli': '5.68.0', railway: '3.16.0' })
  assert.equal(packageDefinition.engines.node, pins.node.version)
  assert.deepEqual(lock.packages[''].dependencies, packageDefinition.dependencies)
  for (const [name, version] of Object.entries(packageDefinition.dependencies)) {
    const entry = lock.packages[`node_modules/${name}`]
    assert.equal(entry.version, version)
    assert.match(entry.resolved, /^https:\/\/registry\.npmjs\.org\//)
    assert.match(entry.integrity, /^sha512-/)
  }
  assert.match(lock.packages['node_modules/railway'].integrity,
    /^sha512-\/\/vKXubZpO07iJgNyoS\+9Ee3pKk\+3wE\+0KAJPI28GuSKqXG30UeWT4xBkkd6TYuZ4HNh7QPvkVR72Swbmq5kXw==$/)
  assert.match(lock.packages['node_modules/@railway/cli'].integrity,
    /^sha512-Yc\+\+uj\/vuW9R7iXOmUtWRm5hHvcy3Hf7ooHEBTesiHkomh3mtxOcl6ZQr76IfXL1YoebVxom1cZmQFYUxV2G8Q==$/)
})
