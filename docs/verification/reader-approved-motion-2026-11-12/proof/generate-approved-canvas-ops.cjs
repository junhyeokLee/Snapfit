// 승인된 미리보기 함수를 다시 번역하지 않고 그대로 실행해 Canvas 명령을 기록한다.
// 사용: node /tmp/generate-approved-canvas-ops.cjs [manifest.json] [output.json]
// 선택: --manifest PATH --output PATH --width 342 --height 342 --source PATH
'use strict';

const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');

const options = {
  source: '/tmp/snapfit-approved-spread-reference.js',
  output: '/tmp/snapfit-approved-reference-ops.json',
  width: 342,
  height: 342,
};
const positional = [];
for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg.startsWith('--')) {
    const key = arg.slice(2);
    if (!['manifest', 'output', 'width', 'height', 'source'].includes(key)) {
      throw new Error(`알 수 없는 옵션: ${arg}`);
    }
    const value = process.argv[++i];
    if (value == null) throw new Error(`${arg} 값이 필요합니다.`);
    options[key] = ['width', 'height'].includes(key) ? Number(value) : value;
  } else positional.push(arg);
}
if (positional[0]) options.manifest = positional[0];
if (positional[1]) options.output = positional[1];
if (positional.length > 2) throw new Error('위치 인자는 manifest와 output 두 개만 받습니다.');

const manifest = options.manifest
  ? JSON.parse(fs.readFileSync(options.manifest, 'utf8'))
  : {};
const width = options.width;
const height = options.height;
// 실제 캡처 이미지가 논리 지면보다 고해상도여도 원본의 이미지 좌표 변환을 보존한다.
const imageWidth = Number(manifest.cellW ?? manifest.cellWidth ?? manifest.atlas?.cellW ?? width);
const imageHeight = Number(manifest.cellH ?? manifest.cellHeight ?? manifest.atlas?.cellH ?? height);
for (const [name, value] of Object.entries({ width, height, imageWidth, imageHeight })) {
  if (!Number.isFinite(value) || value <= 0) throw new Error(`${name}은 양수여야 합니다.`);
}

const source = fs.readFileSync(options.source, 'utf8');
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const names = ['triangle', 'leafVertices', 'drawLeaf'];
const functions = names.map(name => {
  // 원본은 IIFE 바로 아래 4칸 들여쓰기 함수다. 내부 블록은 더 깊게 들여쓴다.
  const expression = new RegExp(`^    function ${name}\\([^\\n]*\\) \\{[\\s\\S]*?^    \\}`, 'm');
  const result = source.match(expression);
  if (!result || source.match(new RegExp(`function ${name}\\(`, 'g'))?.length !== 1) {
    throw new Error(`원본 함수 경계를 확인할 수 없습니다: ${name}`);
  }
  return result[0];
});
const extractedSource = functions.join('\n\n');

let ops = [];
const snapshot = value => JSON.parse(JSON.stringify(value));
const ctx = {};
for (const name of ['save', 'restore', 'beginPath', 'moveTo', 'lineTo', 'closePath', 'clip', 'transform', 'fillRect', 'fill']) {
  ctx[name] = (...args) => ops.push({ op: name, args });
}
ctx.drawImage = (image, ...args) => {
  if (!Number.isInteger(image?._index)) throw new Error('알 수 없는 이미지입니다.');
  ops.push({ op: 'drawImage', args: [image._index, ...args] });
};
ctx.createLinearGradient = (x0, y0, x1, y1) => {
  const gradient = { x0, y0, x1, y1, stops: [] };
  return {
    gradient,
    addColorStop(offset, color) { gradient.stops.push([offset, color]); },
  };
};
Object.defineProperty(ctx, 'fillStyle', {
  set(value) {
    ops.push({ op: 'fillStyle', value: typeof value === 'string' ? value : snapshot({ gradient: value.gradient }) });
  },
});
const sandbox = { ctx, width, height, Math };
vm.createContext(sandbox);
// 수식·조명·그림자·UV 모두 승인된 JavaScript 함수 본문을 직접 실행한다.
vm.runInContext(`${extractedSource}\nglobalThis.approvedDrawLeaf = drawLeaf;`, sandbox, {
  filename: options.source,
  timeout: 1000,
});

const images = Array.from({ length: 4 }, (_, index) => ({ _index: index, width: imageWidth, height: imageHeight }));
const frames = [0, 0.25, 0.5, 0.75, 1].map(progress => {
  ops = [];
  // 제품의 책 받침·제본 장식은 비교하지 않고 동일한 실제 지면 두 장을 바닥에 둔다.
  ctx.drawImage(images[0], -width, 0, width, height);
  ctx.drawImage(images[3], 0, 0, width, height);
  sandbox.frontImage = images[1];
  sandbox.backImage = images[2];
  sandbox.progress = progress;
  vm.runInContext('approvedDrawLeaf(frontImage, backImage, progress);', sandbox, { timeout: 1000 });
  const frameOps = ops;
  const badNumber = frameOps.some(op => op.args?.some(value => typeof value === 'number' && !Number.isFinite(value)));
  if (badNumber) throw new Error(`유효하지 않은 Canvas 좌표: p=${progress}`);
  return { progress, ops: frameOps };
});

const output = {
  source: {
    path: options.source,
    sha256: sha256(source),
    functions: names,
    extractedSha256: sha256(extractedSource),
  },
  width,
  height,
  imageWidth,
  imageHeight,
  coordinateSystem: 'spine-origin',
  canvasTranslation: [width, 0],
  worldBounds: { left: -width, top: 0, width: width * 2, height },
  images: ['base-left/app1', 'leaf-front/app2', 'leaf-back/app3', 'base-right/app4'].map((role, index) => ({ index, role })),
  frames,
};
fs.writeFileSync(options.output, `${JSON.stringify(output, null, 2)}\n`);
process.stdout.write(`${JSON.stringify({ output: options.output, sourceSha256: output.source.sha256, imageWidth, imageHeight, frames: frames.map(frame => ({ progress: frame.progress, commands: frame.ops.length })) })}\n`);
