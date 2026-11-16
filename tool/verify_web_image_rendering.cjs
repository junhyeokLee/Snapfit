#!/usr/bin/env node
// Compare original and packed fonts in the exact CanvasKit shipped by Flutter.
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root=process.cwd();
const pairs=JSON.parse(fs.readFileSync(process.argv[2]||'output/image-render-pairs.json','utf8'));
const server=http.createServer((req,res)=>{
 const relative=decodeURIComponent(new URL(req.url,'http://localhost').pathname).slice(1);
 const file=path.resolve(root,relative);
 if(relative&&!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
 if(!relative){res.setHeader('Content-Type','text/html');res.end('<!doctype html><title>Font equivalence check</title>');return;}
 if(!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return;}
 const mime={'.js':'application/javascript','.wasm':'application/wasm','.woff2':'font/woff2','.ttf':'font/ttf','.otf':'font/otf'};
 res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');
 fs.createReadStream(file).pipe(res);
});
(async()=>{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 try{
  const page=await browser.newPage();
  await page.goto(base);
  const checks=await page.evaluate(async({base,pairs})=>{
   const {default:CanvasKitInit}=await import(base+'build/performance-before-web/canvaskit/canvaskit.js');
   const kit=await CanvasKitInit({locateFile:file=>base+'build/performance-before-web/canvaskit/'+file});
   const digest=async data=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',data))).map(x=>x.toString(16).padStart(2,'0')).join('');
   async function render(file){
    const response=await fetch(base+file);
    if(!response.ok)throw new Error(file+': HTTP '+response.status);
    const bytes=await response.arrayBuffer();
    const image=kit.MakeImageFromEncoded(bytes);
    if(!image)throw new Error('Unsupported image '+file);
    const width=image.width(),height=image.height();
    const pixels=image.readPixels(0,0,{width,height,colorType:kit.ColorType.RGBA_8888,alphaType:kit.AlphaType.Unpremul,colorSpace:kit.ColorSpace.SRGB});
    if(!pixels)throw new Error('No image pixels '+file);
    const pixelSha=await digest(pixels);
    image.delete();return {width,height,pixelSha};
   }
   const results=[];
   for(const pair of pairs){
    const original=await render(pair.source),packed=await render(pair.packed);
    results.push({source:pair.source,packed:pair.packed,width:original.width,height:original.height,metricsEqual:original.width===packed.width&&original.height===packed.height,pixelsEqual:original.pixelSha===packed.pixelSha,sourcePixelSha:original.pixelSha,packedPixelSha:packed.pixelSha});
   }
   return results;
  },{base,pairs});
  const report={passed:checks.every(x=>x.metricsEqual&&x.pixelsEqual),renderer:'Pinned Flutter CanvasKit image codec; complete RGBA pixels in sRGB with unpremultiplied alpha',checks};
  fs.writeFileSync('output/web-image-rendering-check.json',JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({passed:report.passed,uniqueImages:checks.length,failed:checks.filter(x=>!x.metricsEqual||!x.pixelsEqual)},null,2));
  assert.equal(report.passed,true);
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);server.close();process.exitCode=1;});
