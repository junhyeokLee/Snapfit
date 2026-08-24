#!/usr/bin/env python3
"""Source no-key free stock candidates from LibreShot.

LibreShot publishes free stock photos by Martin Vorel for commercial use; still
review current site/license terms before app release and record attribution/source.
"""
from __future__ import annotations
import argparse, json, re, time, urllib.parse, urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
UA='Mozilla/5.0 Snapfit template sourcing/1.0'
BASE='https://libreshot.com/'
QUERIES={
 'jeju_travel_v1':['travel friends','airport luggage','road trip car window','coffee table travel','friends beach','market food hands','hotel room suitcase','sunset couple silhouette','photos travel flatlay'],
 'wedding_editorial_v1':['wedding couple','wedding bouquet','wedding rings','wedding hands','wedding table flowers'],
 'save_the_date_v1':['engagement couple','wedding date card','wedding rings flowers','couple hands flowers','wedding invitation flowers','bride groom','wedding dress','wedding couple Prague','wedding table flowers'],
 'soft_babybook_v1':['baby feet','baby hand','baby blanket','baby toy','nursery toys','parent baby hands','baby bed','child room','baby clothes'],
 'family_weekend_v1':['family picnic','children hands','family walk','dining table family'],
 'film_diary_v1':['film camera','printed photos','coffee camera','street friends'],
 'scrapbook_v1':['printed photos','scrapbook paper','coffee photos','tape photos'],
}

def slug(s): return re.sub(r'[^a-z0-9]+','_',s.lower()).strip('_')[:60]
def template_slug(t): return re.sub(r'_v\d+$','',t)
def fetch(url):
 req=urllib.request.Request(url,headers={'User-Agent':UA})
 with urllib.request.urlopen(req,timeout=30) as r: return r.read()
def search(q):
 url=BASE+'?'+urllib.parse.urlencode({'s':q})
 html=fetch(url).decode('utf-8','ignore')
 urls=[]
 # prefer full-size upload URLs in srcset/html, ignore logos and tiny assets
 for m in re.finditer(r'https://libreshot\.com/wp-content/uploads/\d{4}/\d{2}/[^"\'\s,)]+\.(?:jpg|jpeg|png)',html):
  u=m.group(0).replace('-508x332','').replace('-768x501','').replace('-1536x1003','').replace('-1024x669','')
  if any(bad in u.lower() for bad in ['logo','design.jpg','avatar','favicon']): continue
  if u not in urls: urls.append(u)
 return urls

def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--template',default='jeju_travel_v1'); ap.add_argument('--per-role',type=int,default=3); ap.add_argument('--dry-run',action='store_true')
 args=ap.parse_args(); qs=QUERIES.get(args.template)
 if not qs: raise SystemExit(f'No query set for {args.template}')
 out=ROOT/'assets/templates'/template_slug(args.template)/'images/libreshot_candidates'; out.mkdir(parents=True,exist_ok=True)
 meta={'templateId':args.template,'source':'LibreShot','license':'LibreShot free stock photos; verify current terms before release: https://libreshot.com/','photographer':'Martin Vorel / LibreShot where applicable','downloadedAt':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'reviewStatus':'candidates-only-needs-human-visual-review','candidates':[]}
 seen=set()
 for i,q in enumerate(qs,1):
  print('query',i,q); kept=0
  try: urls=search(q)
  except Exception as e: print('WARN search failed',e); continue
  for u in urls:
   if kept>=args.per_role: break
   if u in seen: continue
   seen.add(u); rel=Path('assets/templates')/template_slug(args.template)/'images/libreshot_candidates'/f'{i:02d}_{slug(q)}__{kept+1}{Path(urllib.parse.urlparse(u).path).suffix.lower() or ".jpg"}'
   item={'roleIndex':i,'query':q,'asset':str(rel),'sourceUrl':u,'license':'LibreShot free stock/commercial use; verify current terms','status':'candidate-needs-review'}
   if args.dry_run: print(' candidate',u); meta['candidates'].append(item); kept+=1; continue
   try:
    data=fetch(u)
    if len(data)<10000: continue
    (ROOT/rel).write_bytes(data); print(' saved',rel); meta['candidates'].append(item); kept+=1
   except Exception as e: print('WARN download failed',u,e)
 (out/'libreshot_candidates.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
 print('total',len(meta['candidates']),'metadata',(out/'libreshot_candidates.json').relative_to(ROOT))
if __name__=='__main__': main()
