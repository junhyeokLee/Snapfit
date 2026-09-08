import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';

void main() {
  group('coverSizes', () {
    test('가로형과 정사각형 실제 제작 규격 5종 존재', () {
      expect(coverSizes.length, 5);
      expect(coverSizes.any((s) => s.name == '세로형'), isFalse);
    });

    test('기존 세로형 앨범은 비율 6/8로 복원', () {
      final vertical = resolveCoverSize(ratio: 6 / 8);
      expect(vertical.ratio, 6 / 8);
    });

    test('가로형 비율 8/6', () {
      final horizontal = coverSizes.firstWhere((s) => s.name == '가로형');
      expect(horizontal.ratio, 8 / 6);
    });

    test('정사각형 비율 1', () {
      final square = coverSizes.firstWhere((s) => s.name == '정사각형');
      expect(square.ratio, 1.0);
    });

    test('같은 방향의 크기도 상품 ID로 구분한다', () {
      final small = coverSizeForProduct('REDP_200_SOFT')!;
      final large = coverSizeForProduct('REDP_300_SOFT')!;
      expect(small.ratio, large.ratio);
      expect(small.realSize, isNot(large.realSize));
    });
  });
}
