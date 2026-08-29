import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snap_fit/main.dart';

/// 테스트용 SnapFit 앱을 pump합니다.
/// Firebase 초기화 없이 ProviderScope + ScreenUtilInit + MoaEditorApp만 사용합니다.
///
/// [overrides]로 provider를 override해 API/저장소 등을 mock할 수 있습니다.
///
/// 예:
/// ```dart
/// await pumpSnapFitApp(tester, overrides: [
///   homeViewModelProvider.overrideWith((_) => ...),
/// ]);
/// ```
Future<void> pumpSnapFitApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => const MoaEditorApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
