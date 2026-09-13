import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../build/template-preview');
const types = {'.html':'text/html; charset=utf-8','.mjs':'text/javascript','.js':'text/javascript',
  '.css':'text/css','.png':'image/png','.jpg':'image/jpeg','.ttf':'font/ttf','.mp4':'video/mp4'};
const server = http.createServer((req, res) => {
  let relative;
  try {relative = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);} catch {res.writeHead(400).end(); return;}
  let file = path.resolve(root, `.${relative}`);
  if (!file.startsWith(root + path.sep) && file !== root) {res.writeHead(403).end();return;}
  try {
    if (fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
    const stat = fs.statSync(file);
    const range = req.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
    const start = range ? Number(range[1]) : 0;
    const end = range?.[2] ? Math.min(Number(range[2]), stat.size - 1) : stat.size - 1;
    if (start > end) {res.writeHead(416).end();return;}
    res.writeHead(range ? 206 : 200, {'Content-Type':types[path.extname(file)] || 'application/octet-stream',
      'Content-Length':end-start+1,'Cache-Control':'no-cache','Accept-Ranges':'bytes',
      ...(range ? {'Content-Range':`bytes ${start}-${end}/${stat.size}`} : {})});
    fs.createReadStream(file, {start, end}).pipe(res);
  } catch {res.writeHead(404).end();}
});
let port = Number(process.env.PORT || 4323);
server.on('error', error => {
  if (error.code !== 'EADDRINUSE') throw error;
  server.listen(++port, '127.0.0.1');
});
server.on('listening', () => console.log(`Brand studio: http://127.0.0.1:${port}/brand/`));
server.listen(port, '127.0.0.1');
