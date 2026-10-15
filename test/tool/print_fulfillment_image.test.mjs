import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { checkedRuntime, checkedFixtureSummary } from '../../tool/print_fulfillment/railway/verify_image.mjs'

const pins = JSON.parse(await readFile(new URL('../../tool/print_fulfillment/linux/runtime-pins.json', import.meta.url)))
const flutter = { frameworkVersion: pins.flutter.version, frameworkRevision: pins.flutter.frameworkRevision, dartSdkVersion: pins.flutter.dartVersion }
test('wrong platform or framework revision cannot be presented as a verified Linux image', () => {
  checkedRuntime(pins, pins.node.version, flutter, 'linux', 'x64')
  assert.throws(() => checkedRuntime(pins, pins.node.version, flutter, 'darwin', 'arm64'))
  assert.throws(() => checkedRuntime(pins, pins.node.version, { ...flutter, frameworkRevision: 'another-engine' }, 'linux', 'x64'))
})
test('fixture evidence requires the actual exported manifest and complete PDFs', () => {
  const rendered = { cover: Buffer.from('%PDF-1.4\n'), interior: Buffer.from('%PDF-1.4\n'),
    manifest: { renderer: 'flutter-layer-builder-raster-v1', pageCount: 80, missingAssets: [] } }
  assert.equal(checkedFixtureSummary('HARD_80', rendered, 123).scenario, 'HARD_80')
  assert.throws(() => checkedFixtureSummary('SOFT_20', rendered, 123))
  assert.throws(() => checkedFixtureSummary('HARD_80', { ...rendered, interior: Buffer.alloc(0) }, 123))
  assert.throws(() => checkedFixtureSummary('HARD_80', { ...rendered, manifest: { ...rendered.manifest, missingAssets: ['missing'] } }, 123))
})
