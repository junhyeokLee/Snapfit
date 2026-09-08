import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const source = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(source, '../..');
const out = path.join(repo, 'build/template-preview/brand');
await fs.mkdir(path.join(out, 'assets'), {recursive: true});
await fs.mkdir(path.join(out, 'vendor'), {recursive: true});
for (const file of ['index.html', 'studio.css', 'studio.mjs']) {
  await fs.copyFile(path.join(source, file), path.join(out, file));
}
for (const file of ['wordmark-cyan.png', 'app-icon-cyan.png', 'splash-portrait.png', 'splash-landscape.png']) {
  await fs.copyFile(path.join(repo, 'assets/brand/album-mark', file), path.join(out, 'assets', file));
}
await fs.copyFile(path.join(repo, 'assets/fonts/NotoSansKR-Regular.ttf'), path.join(out, 'assets', 'sans.ttf'));
await fs.copyFile(path.join(source, 'node_modules/lucide/dist/umd/lucide.js'), path.join(out, 'vendor', 'lucide.js'));
await fs.writeFile(path.join(out, 'assets/README.txt'),
  'SnapFit album-mark brand concept. Original PNG assets: assets/brand/album-mark.\n' +
  'Static AI-generated design concepts only. Not installed in the app. No video is included.\n');
console.log(`Built ${out}\nPreview: http://127.0.0.1:4323/brand/`);
