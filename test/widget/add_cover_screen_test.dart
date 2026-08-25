import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/views/add_cover_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(home: child),
    ),
  );
}

void main() {
  testWidgets(
    'create flow cover atelier focuses cover and contextual actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          AddCoverScreen(
            isFromCreateFlow: true,
            initialCoverSize: coverSizes.firstWhere((s) => s.name == '정사각형'),
            albumTitle: '제주 여름 기록',
            targetPages: 24,
            onAlbumCreated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('표지 문구'), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsOneWidget);
      expect(find.text('편집 시작'), findsOneWidget);
      expect(find.textContaining('함께 볼 사람'), findsNothing);
      expect(find.textContaining('초대'), findsNothing);
      expect(find.byType(EditorBottomMenu), findsNothing);
    },
  );

  testWidgets(
    'create flow cover atelier uses motion wrappers for premium entry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          AddCoverScreen(
            isFromCreateFlow: true,
            initialCoverSize: coverSizes.firstWhere((s) => s.name == '정사각형'),
            albumTitle: '제주 여름 기록',
            targetPages: 24,
            onAlbumCreated: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('coverAtelierEntryFade')), findsOneWidget);
      expect(find.byKey(const Key('coverAtelierEntrySlide')), findsOneWidget);
      expect(
        find.byKey(const Key('coverAtelierPrimaryPressScale')),
        findsOneWidget,
      );
    },
  );
}
