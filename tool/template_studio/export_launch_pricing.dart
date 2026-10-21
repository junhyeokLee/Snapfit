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
    'scope': '42-free-26-approved-premium-154-materials',
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
  book.writeln('\n무료 42종은 0P, 완성 볼륨 7종은 2,500P, 컨셉형 7종은 1,800P다.');
  book.writeln('신규 아틀리에 7종과 스튜디오 유료 5종은 각 2,800P로 등록 승인됐다.');
  book.writeln('가족·친구와 반려동물 무료 에디션은 0P를 유지한다.');
  book.writeln(
    '웨딩·성장 신규 4종: 무료 각 24쪽, 유료 각 32쪽 2,800P. 전용 프레임은 웨딩 각 400P, 성장 각 300P다.',
  );
  book.writeln('편집 문구용 쓰기 종이 4종은 0P 기본 무료 소재로 추가했다.');
  book.writeln('컨셉 전용 사진 프레임 7종은 각 400P로 등록 승인됐다.');
  book.writeln(
    '아틀리에 소재 28종은 기본 종이 7종 0P, 장식 띠 7종 100P, 포토 매트 7종 200P, 투명 오브젝트 7종 300P로 등록 승인됐다.',
  );
  book.writeln(
    '전체 222종을 활성화하는 적용 자료다. 등록 승인은 원격 실행 완료를 뜻하지 않는다. 실제 판매 상태는 서버 적용 및 검증 기록을 따르며, 이 파일은 구매 권한을 지급하지 않는다.',
  );
  File('${output.path}/PRICES.md').writeAsStringSync(book.toString());
  return data;
}
