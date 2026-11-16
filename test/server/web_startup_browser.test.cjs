const {test}=require('node:test');
const assert=require('node:assert/strict');
let chromium;
try { ({chromium}=require('playwright')); } catch (_) { /* Optional browser QA dependency. */ }
const http=require('node:http');
const fs=require('node:fs');
const {execFileSync}=require('node:child_process');

const worker=`self.addEventListener('install',()=>self.skipWaiting());self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));self.addEventListener('fetch',event=>{const path=new URL(event.request.url).pathname;if(path.endsWith('/FontManifest.json'))event.respondWith(Promise.resolve(new Response(JSON.stringify([{family:'MaterialIcons',fonts:[{asset:'fonts/MaterialIcons-Regular.otf'}]}]),{headers:{'Content-Type':'application/json'}})));else if(path.endsWith('MaterialIcons-Regular.otf'))event.respondWith(Promise.resolve(new Response('OLD SUBSET')));});`;
function appHtml(startup) { return `<!doctype html><base href="/"><script>
sessionStorage.setItem('starts',String(Number(sessionStorage.getItem('starts')||0)+1));
window._flutter={loader:{load:async({onEntrypointLoaded})=>{return onEntrypointLoaded({initializeEngine:async()=>{sessionStorage.setItem('engines',String(Number(sessionStorage.getItem('engines')||0)+1));const icon=await(await fetch('/assets/fonts/MaterialIcons-Regular.otf')).text();return{runApp:async()=>{sessionStorage.setItem('icon',icon);window.fixtureDone=true;}};}});}}};
</script><script>${startup}</script>`; }
test('legacy Flutter worker retires before engine without deleting auth, drafts, photos or push worker', {timeout:60000,skip:!chromium||!fs.existsSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')?'Requires Playwright and Chrome for isolated browser QA':false},async()=>{
 const startup=execFileSync('python3',['-c','import tool.build_web as b; print(b.STARTUP)'],{encoding:'utf8'});
 const app=appHtml(startup);
 const server=http.createServer((req,res)=>{
  const pathname=new URL(req.url,'http://localhost').pathname;
  if(pathname.endsWith('.js')){res.setHeader('Content-Type','application/javascript');res.end(pathname==='/flutter_service_worker.js'?worker:"self.addEventListener('install',()=>self.skipWaiting());self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));");return;}
  if(pathname==='/assets/FontManifest.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify([{family:'MaterialIcons',fonts:[{asset:'fonts/MaterialIcons-Regular.otf'}]}]));return;}
  if(pathname.endsWith('MaterialIcons-Regular.otf')){res.end('LATEST SUBSET');return;}
  res.setHeader('Content-Type','text/html');res.end(pathname==='/install'?'<title>Worker setup</title>':app);
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 try{
  const page=await browser.newPage();await page.goto(base+'/install');
  await page.evaluate(async()=>{
   localStorage.setItem('auth-fixture','same-account');
   const db=await new Promise((resolve,reject)=>{const req=indexedDB.open('snapfit-fixture',1);req.onupgradeneeded=()=>req.result.createObjectStore('drafts');req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});
   await new Promise((resolve,reject)=>{const tx=db.transaction('drafts','readwrite');tx.objectStore('drafts').put('same-album-photo','draft');tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);});db.close();
   const cache=await caches.open('snapfit-user-photo-fixture');await cache.put('/private-photo',new Response('ORIGINAL PHOTO BYTES'));
   await navigator.serviceWorker.register('/push/firebase-messaging-sw.js',{scope:'/push/'});
   await navigator.serviceWorker.register('/flutter_service_worker.js',{scope:'/'});
   await navigator.serviceWorker.ready;
   if(!navigator.serviceWorker.controller)await new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true}));
  });
  assert.match(await page.evaluate(()=>navigator.serviceWorker.controller.scriptURL),/flutter_service_worker/);
  await page.goto(base+'/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.fixtureDone===true,null,{timeout:15000});
  const result=await page.evaluate(async()=>{
   const db=await new Promise(resolve=>{const req=indexedDB.open('snapfit-fixture',1);req.onsuccess=()=>resolve(req.result);});
   const draft=await new Promise(resolve=>{const req=db.transaction('drafts').objectStore('drafts').get('draft');req.onsuccess=()=>resolve(req.result);});db.close();
   return{starts:sessionStorage.getItem('starts'),engines:sessionStorage.getItem('engines'),icon:sessionStorage.getItem('icon'),auth:localStorage.getItem('auth-fixture'),draft,photo:await(await(await caches.open('snapfit-user-photo-fixture')).match('/private-photo')).text(),workers:(await navigator.serviceWorker.getRegistrations()).map(r=>r.active?.scriptURL),controller:navigator.serviceWorker.controller?.scriptURL||null};
  });
  fs.writeFileSync('output/web-startup-legacy-browser-check.json',JSON.stringify(result,null,2)+'\n');
  assert.equal(result.starts,'2');assert.equal(result.engines,'1');assert.equal(result.icon,'LATEST SUBSET');
  assert.equal(result.auth,'same-account');assert.equal(result.draft,'same-album-photo');assert.equal(result.photo,'ORIGINAL PHOTO BYTES');
  assert.equal(result.controller,null);assert.equal(result.workers.length,1);assert.match(result.workers[0],/firebase-messaging-sw/);
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
});
