#!/usr/bin/env node
// Isolated guest sessions only; does not use the user's browser profile.
const { chromium } = require('playwright');
const fs = require('node:fs');
const args = Object.fromEntries(process.argv.slice(2).map(value => { const i=value.indexOf('='); return [value.slice(2,i),value.slice(i+1)]; }));
const url = args.url || 'https://snapfit-c719d.web.app/feed';
const runs = Number(args.runs || 1);
const mbps = Number(args['download-mbps'] || 10);
(async () => {
 const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 const measurements=[];
 try {
  for(let run=0;run<runs;run++) {
   const context=await browser.newContext({viewport:{width:1440,height:900}});
   const page=await context.newPage();
   if(args['font-manifest']){
    const body=fs.readFileSync(args['font-manifest'],'utf8');
    await page.route('**/assets/FontManifest.json',route=>route.fulfill({status:200,contentType:'application/json',headers:{'Cache-Control':'no-cache'},body}));
   }
   if(args['preload-font-manifest']){
    const manifest=JSON.parse(fs.readFileSync(args['preload-font-manifest'],'utf8'));
    const fonts=[...new Set(manifest.flatMap(family=>family.fonts.map(font=>font.asset)).filter(asset=>asset.startsWith('assets/fonts/')))];
    await page.addInitScript(fonts=>{
     document.addEventListener('DOMContentLoaded',()=>{
      for(const asset of fonts){const link=document.createElement('link');link.rel='preload';link.as='fetch';link.crossOrigin='anonymous';link.fetchPriority='low';link.href=new URL('assets/'+asset,document.baseURI).href;document.head.append(link);}
     },{once:true});
    },fonts);
   }
   const session=await context.newCDPSession(page);
   await session.send('Network.enable');
   await session.send('Network.setCacheDisabled',{cacheDisabled:true});
   await session.send('Network.emulateNetworkConditions',{offline:false,latency:50,downloadThroughput:mbps*1000000/8,uploadThroughput:2000000/8,connectionType:'cellular4g'});
   const resources=new Map();
   session.on('Network.responseReceived', e=>{
    const u=new URL(e.response.url);
    resources.set(e.requestId,{path:u.origin+u.pathname,status:e.response.status,mime:e.response.mimeType,encoding:e.response.headers['content-encoding']||e.response.headers['Content-Encoding']||null});
   });
   session.on('Network.loadingFinished', e=>{
    const entry=resources.get(e.requestId);
    if(entry) Object.assign(entry,{bytes:e.encodedDataLength,finishedAt:Date.now()});
   });
   const errors=[];
   const consoleErrors=[];
   const requests=[];
   const failedRequests=[];
   page.on('pageerror', error=>errors.push(error.message));
   page.on('console', message=>{if(message.type()==='error')consoleErrors.push(message.text());});
   page.on('request', request=>{const u=new URL(request.url());requests.push(u.origin+u.pathname);});
   page.on('requestfailed', request=>{const u=new URL(request.url());failedRequests.push({path:u.origin+u.pathname,error:request.failure()?.errorText});});
   await page.addInitScript(()=>{
    window.__snapfitFirstFrame=null;
    window.addEventListener('flutter-first-frame',()=>{window.__snapfitFirstFrame={ms:performance.now(),wall:Date.now()};},{once:true});
   });
   try {
    await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
    await page.waitForFunction(()=>window.__snapfitFirstFrame!==null,null,{timeout:120000});
   } catch(error) {
    const output=args.output||'output/web-startup-measurement.json';
    const diagnostic={url,run:run+1,error:error.message,pageErrors:errors,consoleErrors,
      requests,failedRequests,resources:[...resources.values()],completedMeasurements:measurements,
      bodyText:await page.locator('body').innerText().catch(()=>null),
      browser:await browser.version()};
    fs.writeFileSync(output+'.failure.json',JSON.stringify(diagnostic,null,2)+'\n');
    await page.screenshot({path:output+'.failure.png',fullPage:true}).catch(()=>{});
    throw error;
   }
   const frame=await page.evaluate(()=>window.__snapfitFirstFrame);
   await page.waitForTimeout(300);
   const entries=[...resources.values()].filter(e=>e.finishedAt&&e.finishedAt<=frame.wall);
   const fonts=entries.filter(e=>/\.(?:ttf|otf|woff2)(?:$|\?)/i.test(e.path));
   measurements.push({run:run+1,firstFrameMs:frame.ms,bytesBeforeFirstFrame:entries.reduce((sum,e)=>sum+e.bytes,0),fontBytesBeforeFirstFrame:fonts.reduce((sum,e)=>sum+e.bytes,0),fontRequests:fonts.length,pageErrors:errors,resources:entries});
   await context.close();
  }
 } finally { await browser.close(); }
 const report={url,fontManifestOverride:args['font-manifest']||null,fontPreloadProbe:args['preload-font-manifest']||null,profile:{cache:'disabled',latencyMs:50,downloadMbps:mbps,viewport:{width:1440,height:900}},measurements};
 fs.writeFileSync(args.output||'output/web-startup-measurement.json',JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({url,measurements:measurements.map(({resources,...measurement})=>measurement)},null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
