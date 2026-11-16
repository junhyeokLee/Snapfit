
  (() => {
    const root = document.getElementById('snapfit-spread-turn');
    const data = JSON.parse(document.getElementById('snapfit-spread-data').textContent);
    const book = root.querySelector('.book');
    const canvas = root.querySelector('canvas');
    const ctx = canvas.getContext('2d');
    const output = root.querySelector('.position');
    const hint = root.querySelector('.hint');
    const previous = root.querySelector('[data-turn="-1"]');
    const next = root.querySelector('[data-turn="1"]');
    const assets = new Map();
    const pad = 28;
    const resolution = 720;
    let format = 'square', index = 1, width = 1, height = 1;
    let pages = [], turn = null, pointer = null, raf = 0, epoch = 0;
    let isAnimating = false, ready = false;
    const clamp = (x, lo = 0, hi = 1) => Math.max(lo, Math.min(hi, x));
    const now = () => performance.now();

    // 저장 문서의 선택 규격·레이어 좌표를 그대로 사용한다. 사진을 늘려 채우지 않는다.
    function renderPage(page) {
      const ratio = data.formats[format].ratio;
      const image = document.createElement('canvas');
      image.width = resolution;
      image.height = Math.round(resolution / ratio);
      const c = image.getContext('2d');
      const w = image.width, h = image.height;
      c.fillStyle = '#F6F4EC'; c.fillRect(0, 0, w, h);
      for (const layer of page.layers) {
        const x = layer.x * w, y = layer.y * h;
        const lw = layer.w * w, lh = layer.h * h;
        c.save();
        c.globalAlpha = layer.opacity ?? 1;
        if (layer.type === 'decoration') {
          c.fillStyle = layer.fillColor || '#3F5148'; c.fillRect(x, y, lw, lh);
        } else if (layer.type === 'image' || layer.type === 'sticker') {
          const asset = assets.get(layer.imageUrl);
          if (asset) {
            const scale = Math.min(lw / asset.width, lh / asset.height);
            const aw = asset.width * scale, ah = asset.height * scale;
            c.drawImage(asset, x + (lw-aw)/2, y + (lh-ah)/2, aw, ah);
          }
        } else if (layer.type === 'text') {
          const style = layer.style || {};
          const size = (style.fontSize || 14) * w / page.designWidth;
          const serif = style.fontFamily === 'Eulyoo';
          c.font = `400 ${size}px ${serif ? '"AppleMyungjo", "Batang", serif' : '"Apple SD Gothic Neo", sans-serif'}`;
          c.fillStyle = style.color || '#3F5148';
          c.textBaseline = 'top';
          c.textAlign = layer.align === 'center' ? 'center' : layer.align === 'right' ? 'right' : 'left';
          const origin = layer.align === 'center' ? x+lw/2 : layer.align === 'right' ? x+lw : x;
          let baseline = y;
          const step = size * (style.height || 1.3);
          for (const paragraph of String(layer.text || '').split('\n')) {
            let line = '';
            for (const character of Array.from(paragraph)) {
              if (line && c.measureText(line + character).width > lw) {
                c.fillText(line, origin, baseline); baseline += step; line = '';
              }
              line += character;
            }
            c.fillText(line, origin, baseline); baseline += step;
          }
        }
        c.restore();
      }
      return image;
    }

    // 얇은 종이 조각을 사다리꼴로 투영한다. 각 조각의 끝점이 이어져 휘어진 지면이 된다.
    function triangle(image, source, target) {
      const [s0,s1,s2] = source, [d0,d1,d2] = target;
      const u = s1.x-s0.x, v = s2.x-s0.x, p = s1.y-s0.y, q = s2.y-s0.y;
      const det = u*q-v*p;
      if (Math.abs(det) < 1e-8) return;
      const dx1=d1.x-d0.x, dx2=d2.x-d0.x, dy1=d1.y-d0.y, dy2=d2.y-d0.y;
      const a=(dx1*q-dx2*p)/det, c=(dx2*u-dx1*v)/det;
      const b=(dy1*q-dy2*p)/det, d=(dy2*u-dy1*v)/det;
      ctx.save(); ctx.beginPath();
      ctx.moveTo(d0.x,d0.y); ctx.lineTo(d1.x,d1.y); ctx.lineTo(d2.x,d2.y); ctx.closePath(); ctx.clip();
      ctx.transform(a,b,c,d,d0.x-a*s0.x-c*s0.y,d0.y-b*s0.x-d*s0.y);
      ctx.drawImage(image,0,0); ctx.restore();
    }

    const pageSide = pageIndex => pageIndex % 2 === 0 ? 'left' : 'right';
    const focusedCamera = pageIndex => pageSide(pageIndex) === 'left' ? width : 0;

    // 한 권의 좌우 지면은 제본선을 공유한다. 읽는 쪽만 카메라로 크게 따라간다.
    function makeTurn(direction) {
      const target = index + direction;
      const leaf = direction > 0 ? pageSide(index) === 'right' : pageSide(index) === 'left';
      const front = leaf ? (direction > 0 ? index : target) : null;
      const back = leaf ? front + 1 : null;
      const left = leaf ? front - 1 : Math.min(index,target);
      return {
        direction, target, progress: 0, kind: leaf ? 'leaf' : 'pan',
        front, back, left, right: leaf ? back + 1 : left + 1,
        cameraFrom: focusedCamera(index), cameraTo: focusedCamera(target),
        leafFrom: direction > 0 ? 0 : 1, leafTo: direction > 0 ? 1 : 0,
      };
    }

    function leafVertices(progress) {
      const count = 40, strip = width/count, distance = width*12;
      const vertices = [];
      let x=0, z=0;
      for (let i=0; i<=count; i++) {
        const s=i/count;
        const angle=Math.PI*progress + .28*Math.sin(Math.PI*progress)*Math.pow(s,1.4);
        // 안착 직전에는 원근을 줄여 책끝이 손가락 반대로 부풀지 않게 한다.
        const scale=1+(distance/(distance-z)-1)*Math.sin(Math.PI*progress);
        vertices.push({x:x*scale, top:height/2-height/2*scale, bottom:height/2+height/2*scale, angle});
        const mid=(i+.5)/count;
        const midAngle=Math.PI*progress + .28*Math.sin(Math.PI*progress)*Math.pow(mid,1.4);
        x+=Math.cos(midAngle)*strip; z+=Math.sin(midAngle)*strip;
      }
      return vertices;
    }

    function drawLeaf(frontImage, backImage, progress) {
      if (progress <= .0001) { ctx.drawImage(frontImage,0,0,width,height); return; }
      if (progress >= .9999) { ctx.drawImage(backImage,-width,0,width,height); return; }
      const vertices=leafVertices(progress), count=vertices.length-1;
      const outer=vertices[count].x;
      const shadow=ctx.createLinearGradient(outer-34,0,outer+34,0);
      shadow.addColorStop(0,'#26302100'); shadow.addColorStop(.5,'#26302132'); shadow.addColorStop(1,'#26302100');
      ctx.fillStyle=shadow; ctx.fillRect(outer-34,0,68,height);
      for (let i=0; i<count; i++) {
        const a=vertices[i], b=vertices[i+1];
        if(Math.abs(b.x-a.x)<.02) continue;
        const front=Math.cos((a.angle+b.angle)/2)>0;
        const image=front ? frontImage : backImage;
        // 뒷면은 반대쪽 가장자리부터 샘플링해야 왼쪽에 놓인 글자가 거울상으로 보이지 않는다.
        const s0=(front ? i/count : 1-i/count)*image.width;
        const s1=(front ? (i+1)/count : 1-(i+1)/count)*image.width;
        const quad=[{x:a.x,y:a.top},{x:b.x,y:b.top},{x:b.x,y:b.bottom},{x:a.x,y:a.bottom}];
        triangle(image,[{x:s0,y:0},{x:s1,y:0},{x:s1,y:image.height}],[quad[0],quad[1],quad[2]]);
        triangle(image,[{x:s0,y:0},{x:s1,y:image.height},{x:s0,y:image.height}],[quad[0],quad[2],quad[3]]);
        ctx.beginPath(); ctx.moveTo(quad[0].x,quad[0].y);
        for(let k=1;k<4;k++) ctx.lineTo(quad[k].x,quad[k].y);
        ctx.closePath();
        ctx.fillStyle=`rgba(35,42,34,${(.06+.08*i/count)*Math.sin(Math.PI*progress)})`;
        ctx.fill();
      }
    }

    function drawBookBase(left,right) {
      ctx.save();
      ctx.shadowColor='#26302140'; ctx.shadowBlur=16; ctx.shadowOffsetY=10;
      ctx.fillStyle='#bdb2a0'; ctx.fillRect(-width-4,-2,width*2+8,height+8);
      ctx.restore();
      ctx.fillStyle='#F6F4EC'; ctx.fillRect(-width,0,width*2,height);
      if(pages[left]) ctx.drawImage(pages[left],-width,0,width,height);
      if(pages[right]) ctx.drawImage(pages[right],0,0,width,height);
      for(let y=1;y<=4;y++) {
        ctx.fillStyle=y%2 ? '#c5bda9' : '#eee9dc';
        ctx.fillRect(-width,y+height,width*2,1);
      }
      const spine=ctx.createLinearGradient(-11,0,11,0);
      spine.addColorStop(0,'#695b3a00'); spine.addColorStop(.5,'#695b3a38'); spine.addColorStop(1,'#695b3a00');
      ctx.fillStyle=spine; ctx.fillRect(-11,0,22,height);
    }

    function frameModel() {
      if(!turn) {
        const left=index-index%2;
        return {kind:'rest',left,right:left+1,camera:focusedCamera(index),leafProgress:null,front:null,back:null};
      }
      return {
        kind:turn.kind,left:turn.left,right:turn.right,
        camera:turn.cameraFrom+(turn.cameraTo-turn.cameraFrom)*(turn.kind==='leaf' ? turn.progress*turn.progress*(3-2*turn.progress) : turn.progress),
        leafProgress:turn.kind==='leaf' ? turn.leafFrom+(turn.leafTo-turn.leafFrom)*turn.progress : null,
        front:turn.front,back:turn.back,
      };
    }

    function draw() {
      if (!ready || !pages.length) return;
      const dpr=Math.min(window.devicePixelRatio || 1,2), frame=frameModel();
      ctx.setTransform(dpr,0,0,dpr,0,0);
      ctx.clearRect(0,0,width+pad*2,height+pad*2);
      ctx.save(); ctx.translate(pad+frame.camera,pad);
      drawBookBase(frame.left,frame.right);
      if(frame.kind==='leaf') drawLeaf(pages[frame.front],pages[frame.back],frame.leafProgress);
      ctx.restore();
    }

    function update() {
      const side=pageSide(index)==='left' ? '왼쪽' : '오른쪽';
      output.textContent=ready ? `${index+1} / ${pages.length} · ${side}` : '불러오는 중';
      book.dataset.side=pageSide(index);
      canvas.setAttribute('aria-label',`${side} ${index+1}쪽. 이전·다음 버튼으로도 넘길 수 있어요.`);
      previous.disabled=!ready || index===0 || isAnimating;
      next.disabled=!ready || index===pages.length-1 || isAnimating;
      root.querySelectorAll('[data-format]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.format===format)));
    }

    function resize() {
      width=book.getBoundingClientRect().width;
      height=width/data.formats[format].ratio;
      book.style.aspectRatio=String(data.formats[format].ratio);
      const dpr=Math.min(window.devicePixelRatio || 1,2);
      canvas.width=Math.ceil((width+pad*2)*dpr);
      canvas.height=Math.ceil((height+pad*2)*dpr);
      draw();
    }

    function cancelMotion() {
      epoch++; cancelAnimationFrame(raf); turn=null; pointer=null; isAnimating=false;
      book.classList.remove('dragging');
    }

    function animate(target) {
      if (!turn) return;
      const initial=turn.progress, stamp=now(), generation=++epoch;
      const duration=window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 1 : 330+Math.abs(target-initial)*170;
      isAnimating=true; pointer=null; book.classList.remove('dragging'); update();
      function frame(t) {
        if (generation!==epoch || !turn) return;
        const time=clamp((t-stamp)/duration);
        const eased=1-Math.pow(1-time,3);
        turn.progress=initial+(target-initial)*eased; draw();
        if (time<1) raf=requestAnimationFrame(frame);
        else { if(target===1) index+=turn.direction; turn=null; isAnimating=false; draw(); update(); }
      }
      raf=requestAnimationFrame(frame);
    }

    function step(direction) {
      if (!ready || isAnimating || pointer || index+direction<0 || index+direction>=pages.length) return;
      turn=makeTurn(direction); animate(1);
    }
    previous.addEventListener('click',()=>step(-1));
    next.addEventListener('click',()=>step(1));

    book.addEventListener('pointerdown',event=>{
      if (!ready || isAnimating || pointer || event.isPrimary===false || event.button>0) return;
      pointer={id:event.pointerId,start:event.clientX,last:event.clientX,time:now(),velocity:0};
      book.setPointerCapture(event.pointerId); book.classList.add('dragging');
    });
    book.addEventListener('pointermove',event=>{
      if (!pointer || pointer.id!==event.pointerId || isAnimating) return;
      const dx=event.clientX-pointer.start;
      if (!turn && Math.abs(dx)>5) {
        const direction=dx<0?1:-1;
        if (index+direction<0 || index+direction>=pages.length) return;
        turn=makeTurn(direction);
      }
      const timestamp=now(), dt=timestamp-pointer.time;
      if(dt>0 && event.clientX!==pointer.last) pointer.velocity=(event.clientX-pointer.last)/dt;
      pointer.last=event.clientX; pointer.time=timestamp;
      if (turn) { turn.progress=clamp(-dx*turn.direction/(width*.85)); draw(); }
    });
    function release(event,cancelled=false) {
      if(!pointer || pointer.id!==event.pointerId) return;
      const velocity=now()-pointer.time<120 ? pointer.velocity : 0;
      pointer=null; book.classList.remove('dragging');
      if(turn) {
        const commit=!cancelled && (turn.progress>.38 || (turn.progress>.08 && -velocity*turn.direction>.6));
        animate(commit?1:0);
      }
    }
    book.addEventListener('pointerup',event=>release(event));
    book.addEventListener('pointercancel',event=>release(event,true));
    book.addEventListener('lostpointercapture',event=>release(event,true));

    root.querySelectorAll('[data-format]').forEach(button=>button.addEventListener('click',()=>{
      cancelMotion(); format=button.dataset.format;
      if(ready) pages=data.formats[format].pages.map(renderPage);
      update(); resize();
    }));
    root.addEventListener('keydown',event=>{
      if(event.key==='ArrowRight') { event.preventDefault(); step(1); }
      else if(event.key==='ArrowLeft') { event.preventDefault(); step(-1); }
    });
    new ResizeObserver(()=>{ cancelMotion(); resize(); update(); }).observe(book);
    Promise.all(Object.entries(data.assets).map(([key,url])=>new Promise((resolve,reject)=>{
      const image=new Image(); image.onload=()=>{ assets.set(key,image); resolve(); };
      image.onerror=reject; image.src=url;
    }))).then(()=>{
      pages=data.formats[format].pages.map(renderPage); ready=true; resize(); update();
    }).catch(()=>{
      hint.textContent='사진을 불러오지 못했어요. 미리보기를 다시 열어주세요.';
      hint.setAttribute('role','alert');
    });
    // 검증용 상태는 DOM에만 제공한다. 제품에는 디버그 정보나 설정 패널을 추가하지 않는다.
    root.getTurnState=()=>({index,side:pageSide(index),format,ready,isAnimating,progress:turn?.progress ?? 0,width,height,...frameModel()});
    root.inspectTurn=(direction,progress)=>{
      const saved=turn; turn={...makeTurn(direction),progress:clamp(progress)};
      const model=frameModel(); turn=saved;
      const vertices=model.leafProgress===null ? [] : leafVertices(model.leafProgress);
      return {...model,sourceFront:model.front,sourceBack:model.back,vertices};
    };
  })();
  