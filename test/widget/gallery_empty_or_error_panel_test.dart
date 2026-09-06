import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/album_bottom_sheet.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('permission error offers settings and retry recovery', (
    tester,
  ) async {
    var retried = false;
    var openedSettings = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        GalleryEmptyOrErrorPanel(
          message: '사진 접근 권한이 필요합니다. 권한을 허용해주세요.',
          onRetry: () => retried = true,
          onOpenPhotoSettings: () => openedSettings = true,
        ),
      ),
    );

    expect(find.text('사진 접근 권한이 필요해요'), findsOneWidget);
    expect(find.textContaining('설정에서 사진을 몇 장 더 허용'), findsOneWidget);
    expect(find.text('사진 권한 열기'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('사진 권한 열기'));
    await tester.pump();
    expect(openedSettings, isTrue);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('empty album explains that another album can be selected', (
    tester,
  ) async {
    var retried = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        GalleryEmptyOrErrorPanel(
          message: null,
          onRetry: () => retried = true,
          onOpenPhotoSettings: () {},
        ),
      ),
    );

    expect(find.text('이미지 앨범이 비어 있어요'), findsOneWidget);
    expect(find.textContaining('다른 앨범을 고르거나'), findsOneWidget);
    expect(find.text('다시 불러오기'), findsOneWidget);
    expect(find.text('사진 권한 열기'), findsNothing);

    await tester.tap(find.text('다시 불러오기'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
