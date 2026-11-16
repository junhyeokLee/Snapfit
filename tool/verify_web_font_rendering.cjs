#!/usr/bin/env node
// Compare original and packed fonts in the exact CanvasKit shipped by Flutter.
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root=process.cwd();
const pairs=JSON.parse(fs.readFileSync(process.argv[2]||'output/font-render-pairs.json','utf8'));
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
   const text='우리의 앨범 · 사진과 기록\nAV fi ffi 0123456789 !? 가나다 한글 한';
   const digest=async data=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',data))).map(x=>x.toString(16).padStart(2,'0')).join('');
   async function render(file){
    const response=await fetch(base+file);
    if(!response.ok)throw new Error(file+': HTTP '+response.status);
    const bytes=await response.arrayBuffer();
    const face=kit.Typeface.MakeFreeTypeFaceFromData(bytes);
    if(!face)throw new Error('Unsupported font '+file);
    const manager=kit.FontMgr.FromData(bytes);
    if(!manager)throw new Error('Missing font manager '+file);
    const family=manager.getFamilyName(0);
    const surface=kit.MakeSurface(1200,460);
    const canvas=surface.getCanvas();canvas.clear(kit.WHITE);
    const measurements=[];let y=10;
    for(const size of [12,34,72]){
     const font=new kit.Font(face,size);
     const ids=font.getGlyphIDs(text);
     const widths=Array.from(font.getGlyphWidths(ids));
     const bounds=Array.from(font.getGlyphBounds(ids));
     const builder=kit.ParagraphBuilder.Make(kit.ParagraphStyle({textStyle:{fontFamilies:[family],fontSize:size,color:kit.BLACK},textDirection:kit.TextDirection.LTR}),manager);
     builder.addText(text);const paragraph=builder.build();paragraph.layout(1180);
     canvas.drawParagraph(paragraph,10,y);
     measurements.push({size,glyphs:Array.from(ids),widths,bounds,height:paragraph.getHeight(),longestLine:paragraph.getLongestLine(),intrinsic:paragraph.getMaxIntrinsicWidth()});
     y+=paragraph.getHeight()+12;
     paragraph.delete();builder.delete();font.delete();
    }
    surface.flush();
    const pixels=canvas.readPixels(0,0,{width:1200,height:460,colorType:kit.ColorType.RGBA_8888,alphaType:kit.AlphaType.Unpremul,colorSpace:kit.ColorSpace.SRGB});
    if(!pixels)throw new Error('No pixels '+file);
    const pixelSha=await digest(pixels);
    surface.delete();manager.delete();face.delete();
    return {family,measurements,pixelSha};
   }
   const results=[];
   for(const pair of pairs){
    const original=await render(pair.source),packed=await render(pair.packed);
    results.push({source:pair.source,packed:pair.packed,family:original.family,metricsEqual:JSON.stringify(original.measurements)===JSON.stringify(packed.measurements),pixelsEqual:original.pixelSha===packed.pixelSha,sourcePixelSha:original.pixelSha,packedPixelSha:packed.pixelSha});
   }
   return results;
  },{base,pairs});
  const report={passed:checks.every(x=>x.metricsEqual&&x.pixelsEqual),renderer:'Pinned Flutter CanvasKit software rasterizer; shaped paragraphs plus glyph IDs, bounds and advances at 12/34/72px',checks};
  fs.writeFileSync('output/web-font-rendering-check.json',JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({passed:report.passed,fonts:checks.length,failed:checks.filter(x=>!x.metricsEqual||!x.pixelsEqual)},null,2));
  assert.equal(report.passed,true);
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);server.close();process.exitCode=1;});
