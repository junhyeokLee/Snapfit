import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_daily_journal_intro.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_book_cover.dart';

Future<void> mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  VoidCallback? onRecord,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('나의 기록')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MomentDailyJournalIntro(
            today: DateTime.utc(2026, 10, 28),
            onRecord: onRecord ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'first experience is a dated photo and note, not an already-made book',
    (tester) async {
      var records = 0;
      await mount(tester, onRecord: () => records++);
      expect(find.text('사진 한 장 + 짧은 한 줄'), findsOneWidget);
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.text('오늘의 기록'), findsOneWidget);
      expect(find.text('사진 아래에, 이날의 기분 한 줄'), findsOneWidget);
      expect(find.text('날짜별 기록'), findsOneWidget);
      expect(find.text('월간 앨범'), findsOneWidget);
      expect(find.byType(MomentBookCover), findsNothing);
      expect(find.byType(Image), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('moments-first-photo')),
      );
      await tester.tap(find.text('오늘의 한 장 남기기'));
      expect(records, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the photo placeholder starts the same daily record action exactly once',
    (tester) async {
      var records = 0;
      await mount(tester, onRecord: () => records++);
      final slot = find.byKey(const ValueKey('moments-daily-photo-slot'));
      await tester.ensureVisible(slot);
      await tester.pumpAndSettle();
      await tester.tap(slot);
      expect(records, 1);
      await tester.ensureVisible(
        find.byKey(const ValueKey('moments-first-photo')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('moments-first-photo')));
      expect(records, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final layout in [
    (size: const Size(320, 568), scale: 2.0, dark: false),
    (size: const Size(390, 844), scale: 1.8, dark: true),
    (size: const Size(844, 390), scale: 1.8, dark: false),
    (size: const Size(1280, 960), scale: 1.0, dark: false),
  ]) {
    testWidgets(
      'daily journal stays readable and actionable at ${layout.size} ${layout.scale}',
      (tester) async {
        var taps = 0;
        await mount(
          tester,
          size: layout.size,
          scale: layout.scale,
          dark: layout.dark,
          onRecord: () => taps++,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('moments-first-photo')),
        );
        await tester.pumpAndSettle();
        expect(find.text('오늘의 한 장 남기기').hitTestable(), findsOneWidget);
        await tester.tap(find.text('오늘의 한 장 남기기').hitTestable());
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'weekly entry reports real photographs without an arbitrary completion goal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MomentWeekCard(photoCount: 6, onRecord: () {})),
        ),
      );
      expect(find.text('이번 주 사진 6장'), findsOneWidget);
      expect(find.textContaining('권장 목표'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
