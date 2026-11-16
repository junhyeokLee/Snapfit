const fs=require('node:fs'), vm=require('node:vm'), assert=require('node:assert/strict');
const source='/Users/devsheep/SnapFit/album-spread-turn.html';
const html=fs.readFileSync(source,'utf8');
const data=JSON.parse(html.match(/id="snapfit-spread-data">([\s\S]*?)<\/script>/)[1]);
let time=0,frames=[],resizeCallback,draws=0,canvasCount=0,rootDraws=[],rootTransforms=[];
const finite=(...v)=>{for(const n of v)if(typeof n==='number')assert(Number.isFinite(n));};
function context(main=false) { return new Proxy({font:'14px serif',measureText:t=>({width:Array.from(t).length*7}),createLinearGradient:(...v)=>{finite(...v);return {addColorStop(){}};}},{get(o,k){return k in o?o[k]:(...v)=>{finite(...v);if(k==='drawImage'){draws++;if(main)rootDraws.push(v[0]._pageIndex);}if(k==='transform'&&main)rootTransforms.push(v);};}}); }
class Element {
  constructor(){this.listeners={};this.style={};this.attributes={};this.dataset={};this.classList={add(){},remove(){}};this.disabled=false;this.textContent='';}
  addEventListener(type,fn){(this.listeners[type]??=[]).push(fn);}
  emit(type,event={}){for(const fn of this.listeners[type]||[])fn({button:0,pointerId:1,clientX:0,isPrimary:true,...event});}
  setAttribute(k,v){this.attributes[k]=v;}
  getBoundingClientRect(){return {width:352,height:352};}
  setPointerCapture(){}
}
const root=new Element(),book=new Element(),canvas=new Element(),out=new Element(),prev=new Element(),next=new Element(),hint=new Element();
canvas.getContext=()=>context(true);
const buttons=['square','landscape4x3','landscape5x4'].map(format=>{const b=new Element();b.dataset.format=format;return b;});
const elements={'.book':book,'canvas':canvas,'.position':out,'.hint':hint,'[data-turn="-1"]':prev,'[data-turn="1"]':next};
root.querySelector=q=>{assert(q in elements,q);return elements[q];};
root.querySelectorAll=q=>{assert.equal(q,'[data-format]');return buttons;};
const document={getElementById:id=>id==='snapfit-spread-turn'?root:{textContent:JSON.stringify(data)},createElement:()=>({_pageIndex:canvasCount++%4,getContext:()=>context()})};
class Image {constructor(){this.width=640;this.height=427;}set src(url){assert(url.startsWith('data:image/'));queueMicrotask(()=>this.onload());}}
const sandbox={document,window:{devicePixelRatio:2,matchMedia:()=>({matches:false})},Image,ResizeObserver:class{constructor(fn){resizeCallback=fn;}observe(){}},performance:{now:()=>time},requestAnimationFrame:fn=>{frames.push(fn);return frames.length;},cancelAnimationFrame(){},console};
vm.runInNewContext(html.split('<script>')[1].split('</script>')[0],sandbox,{filename:'album-spread-turn.js'});
const state=()=>root.getTurnState(), inspect=(d,p)=>root.inspectTurn(d,p);
const close=(a,b)=>assert(Math.abs(a-b)<1e-8,`${a} != ${b}`);
const flush=()=>{for(let n=0;frames.length&&n<100;n++){time+=16;const work=frames;frames=[];for(const fn of work)fn(time);}assert.equal(frames.length,0);};
let checks=0;
const check=(label,fn)=>{fn();checks++;console.log('PASS',label);};
const drag=(start,end,{wait=200,cancel=false}={})=>{book.emit('pointerdown',{clientX:start});time+=wait;book.emit('pointermove',{clientX:end});book.emit(cancel?'pointercancel':'pointerup',{clientX:end});flush();};
(async()=>{
  await new Promise(resolve=>setImmediate(resolve));
  check('starts on real right-hand page 2, spine at left',()=>{assert(state().ready);assert.equal(state().index,1);assert.equal(state().side,'right');close(state().camera,0);assert.equal(out.textContent,'2 / 4 · 오른쪽');assert.equal(book.dataset.side,'right');});
  check('next is one physical leaf with front2/back3 and underpages1/4',()=>{const m=inspect(1,.5);assert.equal(m.kind,'leaf');assert.equal(m.front,1);assert.equal(m.back,2);assert.equal(m.left,0);assert.equal(m.right,3);close(m.camera,176);close(m.leafProgress,.5);});
  check('leaf endpoints land on left without mirroring',()=>{const a=inspect(1,0),b=inspect(1,1);close(a.camera,0);close(a.vertices.at(-1).x,352);close(b.camera,352);close(b.vertices.at(-1).x,-352);const src0=1,src1=0,dst0=b.vertices[0].x,dst1=b.vertices.at(-1).x;assert((dst1-dst0)/(src1-src0)>0);});
  check('early leaf tip follows leftward gesture rather than jumping right',()=>{for(const p of [.03,.05,.1,.15]){const m=inspect(1,p);assert(m.vertices.at(-1).x+m.camera<352.6);}});
  book.emit('pointerdown',{clientX:290});time+=220;book.emit('pointermove',{clientX:230});
  check('partial leaf follows primary drag and shows real front page',()=>{assert(state().progress>.1&&state().progress<.38);assert.equal(state().kind,'leaf');assert(rootDraws.includes(1));});
  time+=200;book.emit('pointerup',{clientX:230});flush();
  check('short slow release restores right-hand page and spine',()=>{assert.equal(state().index,1);assert.equal(state().side,'right');close(state().camera,0);});
  book.emit('pointerdown',{clientX:315});time+=200;rootDraws=[];rootTransforms=[];book.emit('pointermove',{clientX:90});
  check('moving back face contains actual page3 art, not blank paper',()=>{assert(state().leafProgress>.5);assert(rootDraws.filter(x=>x===2).length>10);assert(rootTransforms.length>10);assert(rootTransforms.every(m=>m[0]*m[3]-m[1]*m[2]>0));});
  book.emit('pointerup',{clientX:90});flush();
  check('right2 to left3 commits with spine now on right',()=>{assert.equal(state().index,2);assert.equal(state().side,'left');close(state().camera,352);assert.equal(book.dataset.side,'left');assert.equal(out.textContent,'3 / 4 · 왼쪽');});
  check('left3 to right4 stays in same spread and pans without another leaf',()=>{const m=inspect(1,.5);assert.equal(m.kind,'pan');assert.equal(m.left,2);assert.equal(m.right,3);assert.equal(m.front,null);assert.equal(m.back,null);assert.equal(m.leafProgress,null);close(m.camera,176);});
  next.emit('click');flush();
  check('pan reaches right4, disables next, keeps correct side',()=>{assert.equal(state().index,3);assert.equal(state().side,'right');close(state().camera,0);assert(next.disabled);});
  check('previous from right4 is same-spread pan',()=>{const m=inspect(-1,.3);assert.equal(m.kind,'pan');assert.equal(m.left,2);assert.equal(m.right,3);});
  prev.emit('click');flush();
  check('previous from left3 reverses front2/back3 physical leaf',()=>{const a=inspect(-1,0),b=inspect(-1,1);assert.equal(a.kind,'leaf');assert.equal(a.front,1);assert.equal(a.back,2);close(a.camera,352);close(a.leafProgress,1);close(b.camera,0);close(b.leafProgress,0);});
  drag(80,290);
  check('reverse leaf returns right2',()=>{assert.equal(state().index,1);assert.equal(state().side,'right');close(state().camera,0);});
  prev.emit('click');flush();
  check('right2 back to left1 is pan and first bound is protected',()=>{assert.equal(state().index,0);assert.equal(state().side,'left');assert(prev.disabled);close(state().camera,352);prev.emit('click');flush();assert.equal(state().index,0);});
  next.emit('click');flush();
  drag(300,100,{cancel:true});check('pointer cancellation never changes page or side',()=>{assert.equal(state().index,1);assert.equal(state().side,'right');});
  book.emit('pointerdown',{clientX:300});book.emit('pointerdown',{pointerId:2,isPrimary:false,clientX:10});time+=200;book.emit('pointermove',{clientX:70});book.emit('pointerup',{clientX:70});flush();
  check('second finger cannot replace active page turn',()=>assert.equal(state().index,2));
  for(const [button,ratio] of [[buttons[1],4/3],[buttons[2],5/4],[buttons[0],1]]){
    prev.emit('click');button.emit('click');flush();
    check('format '+button.dataset.format+' cancels motion and preserves left/right exact ratio',()=>{assert.equal(state().index,2);assert.equal(state().side,'left');assert(!state().isAnimating);close(state().width/state().height,ratio);close(state().camera,state().width);const m=inspect(-1,.6);for(const v of m.vertices){finite(v.x,v.top,v.bottom,v.angle);}});
  }
  prev.emit('click');resizeCallback();flush();check('resize cancels pending leaf at original page',()=>{assert.equal(state().index,2);assert(!state().isAnimating);});
  check('all mesh coordinates and drawing transforms are finite',()=>assert(draws>100));
  assert(Buffer.byteLength(html)<1000000);
  console.log(`RESULT passed=${checks} failed=0 draws=${draws} preview_bytes=${Buffer.byteLength(html)}`);
})().catch(error=>{console.error(error);process.exitCode=1;});
