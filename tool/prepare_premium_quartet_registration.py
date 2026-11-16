#!/usr/bin/env python3
"""Prepare exact, conflict-checked396-product registration; never executes SQL."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/premium-four-per-topic-20261103'


def main():
    rows=json.loads((OUT/'price-rows.json').read_text())
    assert len(rows)==len({r['product_key'] for r in rows})==396
    assert sum(r['kind']=='template' for r in rows)==44
    assert all(r['is_active'] and r['point_price']>0 for r in rows)
    previous=(ROOT/'output/diversity-expansion-20261103/register-new-products.sql').read_text()
    start=previous.index('$catalog_rows$')+len('$catalog_rows$')
    end=previous.index('$catalog_rows$',start)
    sql=previous[:start]+'__PREMIUM_PRODUCT_ROWS__'+previous[end:]
    sql=sql.replace('70','396').replace('diversity_release','premium_quartet_release')
    sql=sql.replace('-- Register only these 396 delivered diversity products.','-- Register exactly396 delivered premium quartet products (44 books +352 materials).')
    sql=sql.replace('__PREMIUM_PRODUCT_ROWS__',json.dumps(rows,ensure_ascii=False))
    assert json.loads(sql.split('$catalog_rows$')[1])==rows
    (OUT/'register-new-products.sql').write_text(sql)
    print('Prepared396 guarded product registrations; no database write performed.')


if __name__=='__main__':
    main()
