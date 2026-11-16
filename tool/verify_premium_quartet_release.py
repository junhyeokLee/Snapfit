#!/usr/bin/env python3
"""Read-only anonymous store quotes and publication metadata; never buys."""
import argparse
import concurrent.futures
import datetime
import json
import re
import ssl
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--rows', type=Path, required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--require-published',action='store_true')
    args=parser.parse_args()
    source=(ROOT/'lib/config/env.dart').read_text()
    url=re.search(r'supabaseUrl\s*=.*?defaultValue:\s*\'([^\']+)\'',source,re.S).group(1)
    key=re.search(r'supabaseAnonKey\s*=.*?defaultValue:\s*\'([^\']+)\'',source,re.S).group(1)
    def rpc(name,body):
        request=urllib.request.Request(url+'/rest/v1/rpc/'+name,
            data=json.dumps(body).encode(),headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'})
        with urllib.request.urlopen(request,timeout=45,context=ssl.create_default_context(cafile='/etc/ssl/cert.pem')) as response:
            return json.load(response)
    rows=json.loads(args.rows.read_text())
    discovery={row['product_key']:row for row in rpc('get_store_product_discovery',{})}
    def quote(row):
        value=rpc('get_point_shop_access',{'p_product_key':row['product_key']})
        assert value['product_key']==row['product_key']
        assert value['point_price']==row['point_price'],(row['product_key'],value)
        assert value['available'] is True and value['is_free']==(row['point_price']==0),value
        assert value['title']==row['title'],(row['product_key'],value)
        published=discovery[row['product_key']]['first_published_at']
        if args.require_published:
            assert published, row['product_key']
        return {**value,'first_published_at':published}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        quotes=list(pool.map(quote,rows))
    result=dict(verifiedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        anonymous=True,purchasePerformed=False,quotes=quotes,count=len(quotes),
        free=sum(row['is_free'] for row in quotes),paid=sum(not row['is_free'] for row in quotes))
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(f'Anonymous store verified: {result["count"]} active products ({result["paid"]} paid, {result["free"]} free).')


if __name__=='__main__':
    main()
