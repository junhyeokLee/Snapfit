import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_photo.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_summary_card.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_monthly_album_entry.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_monthly_reward_summary.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';

MomentMonthlyReward _reward({bool awarded = false, bool canComplete = true}) =>
    MomentMonthlyReward(
      points: 1000,
      recordedDays: awarded ? 30 : 9,
      daysInMonth: 30,
      awarded: awarded,
      canComplete: canComplete,
    );

MomentJournal _journal({MomentMonthlyReward? reward, bool photo = false}) =>
    MomentJournal(
      today: DateTime.utc(2026, 11, 11),
      weekStart: DateTime.utc(2026, 11, 9),
      month: DateTime.utc(2026, 11),
      records: photo
          ? [
              MomentRecord(
                id: 'record',
                recordDate: DateTime.utc(2026, 11, 10),
                caption: '남겨둔 순간',
                photos: const [
                  MomentPhoto(
                    id: 'photo',
                    path: 'owner/moments/record/photo.png',
                    width: 1200,
                    height: 800,
                  ),
                ],
                revision: 1,
              ),
            ]
          : const [],
      weekPhotoCount: photo ? 1 : 0,
      monthlyReward: reward,
    );

Widget _host(Widget child, {MomentJournal? journal, double scale = 1}) =>
    ProviderScope(
      key: ObjectKey(journal),
      overrides: [
        momentEntryJournalProvider.overrideWith((ref) async => journal),
      ],
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  testWidgets(
    'priority: missed reward still shows accumulated monthly progress',
    (tester) async {
      await tester.pumpWidget(
        _host(MomentMonthlyRewardSummary(reward: _reward(canComplete: false))),
      );
      expect(find.textContaining('9/30일'), findsOneWidget);
      expect(find.textContaining('기록은 계속'), findsOneWidget);
      expect(find.text('적립 완료'), findsNothing);
    },
  );

  testWidgets('home omits rewards and counts for every server reward status', (
    tester,
  ) async {
    for (final reward in [
      null,
      _reward(),
      _reward(canComplete: false),
      _reward(awarded: true),
    ]) {
      await tester.pumpWidget(
        _host(
          HomeMomentSummaryCard(
            onRecord: () {},
            onOpenMonth: () {},
            onOpenDate: (_) {},
            onSignIn: () {},
          ),
          journal: _journal(reward: reward),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-monthly-feed-week')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-monthly-reward')), findsNothing);
      expect(
        find.byKey(const ValueKey('home-monthly-feed-counts')),
        findsNothing,
      );
      expect(find.byType(MomentMonthlyRewardSummary), findsNothing);
      expect(find.textContaining('1,000P'), findsNothing);
      expect(find.textContaining('인정 기록'), findsNothing);
      expect(
        find.byKey(const ValueKey('home-monthly-album-entry')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('missed-day and awarded statuses do not promise another reward', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(MomentMonthlyRewardSummary(reward: _reward(canComplete: false))),
    );
    expect(find.text('기록은 계속 쌓이고 있어요'), findsOneWidget);
    expect(find.text('인정 기록 9/30일 · 이번 달 보상 마감'), findsOneWidget);
    await tester.pumpWidget(
      _host(MomentMonthlyRewardSummary(reward: _reward(awarded: true))),
    );
    expect(find.text('월간 기록 보상 1,000P 적립 완료'), findsOneWidget);
    expect(find.text('한 달을 채우면 1,000P'), findsNothing);
  });

  testWidgets(
    'rules explain monthly reward and same-day editing with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(MomentMonthlyRewardSummary(reward: _reward()), scale: 2),
      );
      await tester.tap(find.byKey(const ValueKey('home-monthly-reward')));
      await tester.pumpAndSettle();
      expect(find.text('월간 기록 보상'), findsOneWidget);
      expect(
        find.textContaining('한 달의 모든 날짜에 사진을 남기면\n1,000P'),
        findsOneWidget,
      );
      expect(find.textContaining('한국 시간 기준 당일'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'month-to-album entry appears for actual photographs and opens selection',
    (tester) async {
      var opens = 0;
      Widget entry(MomentJournal journal) =>
          MomentMonthlyAlbumEntry(journal: journal, onPreview: () => opens++);
      final empty = _journal();
      final saved = _journal(photo: true);
      await tester.pumpWidget(_host(entry(empty)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-monthly-album-entry')),
        findsNothing,
      );
      await tester.pumpWidget(_host(entry(saved)));
      await tester.pumpAndSettle();
      expect(find.text('모은 순간을 한 권의 앨범으로'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-monthly-album-entry')));
      expect(opens, 1);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    },
  );

  for (final dimensions in [(1200, 800), (800, 1200)]) {
    testWidgets(
      'original photo remains contained in the album frame at ${dimensions.$1}:${dimensions.$2}',
      (tester) async {
        final photo = MomentPhoto(
          id: 'ratio',
          path: '',
          width: dimensions.$1,
          height: dimensions.$2,
        );
        await tester.pumpWidget(
          _host(HomeMomentPhoto(photo: photo, width: 148, height: 96)),
        );
        final size = tester.getSize(
          find.byKey(const ValueKey('home-moment-photo-frame-ratio')),
        );
        expect(size.aspectRatio, closeTo(momentPhotoAspect(photo), .0001));
        expect(size.width, lessThanOrEqualTo(148));
        expect(size.height, lessThanOrEqualTo(96));
        final view = tester.widget<MomentPhotoView>(
          find.byType(MomentPhotoView),
        );
        expect(view.fit, BoxFit.contain);
        expect(view.aspectRatio, momentPhotoAspect(photo));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
