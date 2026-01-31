import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';

void main() {
  group('coverSizes', () {
    test('세로형, 가로형, 정사각형 3종 존재', () {
      expect(coverSizes.length, 3);
    });

    test('세로형 비율 6/8', () {
      final vertical = coverSizes.firstWhere((s) => s.name == '세로형');
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

    test('name으로 조회 시 orElse 미사용', () {
      final v = coverSizes.firstWhere(
        (s) => s.name == '세로형',
        orElse: () => coverSizes.first,
      );
      expect(v.name, '세로형');
    });
  });
}
