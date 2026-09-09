import 'dart:convert';
import 'dart:io';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';

/// Readable price book and structured release input. Deliberately emits no SQL.
Map<String, dynamic> exportLaunchPricing(Directory output) {
  final products = {for (final p in pointShopKnownProducts) p.productKey: p};
  final rows = <Map<String, dynamic>>[];
  for (final entry in pointShopLaunchPrices.entries) {
    final product = products[entry.key];
    if (product == null) throw StateError('unregistered_price:${entry.key}');
    rows.add({
      'productKey': entry.key,
      'title': product.title,
      'kind': product.kind,
      'launchPointPrice': entry.value.points,
      'reason': entry.value.reason,
      'status': 'scheduled-not-live',
    });
  }
  final data = <String, dynamic>{
    'revision': pointShopPricingRevision,
    'scope': '37-free-collections-14-premium-collections-83-recent-materials',
    'marketValidated': false,
    'changesCustomerAccess': false,
    'grantsIncludedMaterials': false,
    'products': rows,
  };
  output.createSync(recursive: true);
  File(
    '${output.path}/prices.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  final book = StringBuffer('# SnapFit 출시 책정가\n\n')
    ..writeln('기준: $pointShopPricingRevision. 가격 책정 완료, 실제 판매 활성화 전.')
    ..writeln('현재 운영 가격이나 구매 권한을 변경하는 파일이 아니다.\n')
    ..writeln('| 상품 | 종류 | 책정가 | 기준 |')
    ..writeln('| --- | --- | ---: | --- |');
  const kinds = {
    'template': '템플릿',
    'sticker': '장식',
    'phrase': '문구',
    'frame': '프레임',
  };
  for (final row in rows) {
    book.writeln(
      '| ${row['title']} | ${kinds[row['kind']]} | ${row['launchPointPrice']}P | ${row['reason']} |',
    );
  }
  book.writeln('\n기존 무료 37종은 0P, 완성 볼륨 7종은 2,500P, 컨셉형 7종은 1,800P다.');
  book.writeln(
    '원격 적용 여부는 별도 실행 기록을 따른다. 유료 템플릿의 실제 판매 개시는 콘텐츠 전달과 권한 연결 검증 후 진행한다.',
  );
  File('${output.path}/PRICES.md').writeAsStringSync(book.toString());
  return data;
}
