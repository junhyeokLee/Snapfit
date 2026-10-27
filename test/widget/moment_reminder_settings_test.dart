import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_engagement_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_reminder_settings_screen.dart';

class _Moments extends Mock implements MomentsRepository {}

class _Engagement implements MomentEngagementRepository {
  MomentEngagement value = const MomentEngagement(
    reminder: MomentReminder(),
    hasRecords: true,
  );
  Future<MomentEngagement> Function()? onLoad;
  Future<MomentEngagement> Function(MomentReminder)? onSave;
  final saves = <MomentReminder>[];
  @override
  Future<MomentEngagement> load() async => onLoad?.call() ?? value;
  @override
  Future<MomentEngagement> saveReminder(MomentReminder reminder) async {
    saves.add(reminder);
    return onSave?.call(reminder) ??
        MomentEngagement(reminder: reminder, hasRecords: value.hasRecords);
  }

  @override
  Future<bool> recordActivity(
    MomentActivity activity, {
    DateTime? month,
  }) async => true;
}

void main() {
  late _Moments moments;
  late _Engagement engagement;
  late StreamController<String?> events;
  String? owner;
  setUp(() {
    owner = 'owner';
    events = StreamController<String?>.broadcast(sync: true);
    moments = _Moments();
    engagement = _Engagement();
    when(() => moments.currentUserId).thenAnswer((_) => owner);
    when(() => moments.authChanges).thenAnswer((_) => events.stream);
  });
  tearDown(() => events.close());
  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          momentsRepositoryProvider.overrideWithValue(moments),
          momentEngagementRepositoryProvider.overrideWithValue(engagement),
        ],
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const MomentReminderSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first record is required and reminders are never enabled on load',
    (tester) async {
      engagement.value = const MomentEngagement(
        reminder: MomentReminder(),
        hasRecords: false,
      );
      await mount(tester);
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('moments-reminder-toggle')),
      );
      expect(toggle.value, false);
      expect(toggle.onChanged, isNull);
      expect(find.text('사진 한 장을 남긴 뒤 알림을 켤 수 있어요.'), findsOneWidget);
      expect(engagement.saves, isEmpty);
    },
  );
  testWidgets(
    'draft toggle is saved only by explicit save and persists confirmed state',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('moments-reminder-toggle')));
      await tester.pumpAndSettle();
      expect(engagement.saves, isEmpty);
      await tester.ensureVisible(
        find.byKey(const ValueKey('moments-reminder-save')),
      );
      await tester.tap(find.byKey(const ValueKey('moments-reminder-save')));
      await tester.pumpAndSettle();
      expect(engagement.saves.single.enabled, true);
      expect(engagement.saves.single.weekday, 7);
      expect(find.text('선택한 시간에 주 1회 알려드릴게요.'), findsOneWidget);
    },
  );
  testWidgets('failed save retains choice and can retry', (tester) async {
    engagement.onSave = (_) async =>
        throw const MomentException('연결을 확인해 주세요.');
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('moments-reminder-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('moments-reminder-save')),
    );
    await tester.tap(find.byKey(const ValueKey('moments-reminder-save')));
    await tester.pumpAndSettle();
    expect(find.text('연결을 확인해 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('moments-reminder-toggle')),
          )
          .value,
      true,
    );
    engagement.onSave = null;
    await tester.ensureVisible(
      find.byKey(const ValueKey('moments-reminder-save')),
    );
    await tester.tap(find.byKey(const ValueKey('moments-reminder-save')));
    await tester.pumpAndSettle();
    expect(engagement.saves, hasLength(2));
  });

  testWidgets(
    'disabled master notification setting is explained without promising delivery',
    (tester) async {
      engagement.value = const MomentEngagement(
        reminder: MomentReminder(),
        hasRecords: true,
        canRemind: false,
      );
      engagement.onSave = (reminder) async => MomentEngagement(
        reminder: reminder,
        hasRecords: true,
        canRemind: false,
      );
      await mount(tester);
      expect(find.textContaining('전체 알림이 꺼져 있어요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('moments-reminder-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('moments-reminder-save')),
      );
      await tester.tap(find.byKey(const ValueKey('moments-reminder-save')));
      await tester.pumpAndSettle();
      expect(find.text('시간을 저장했어요. 전체 알림을 켜면 받을 수 있어요.'), findsOneWidget);
      expect(find.text('선택한 시간에 주 1회 알려드릴게요.'), findsNothing);
    },
  );
  testWidgets(
    'account replacement hides preferences and rejects delayed save acknowledgement',
    (tester) async {
      final saved = Completer<MomentEngagement>();
      engagement.onSave = (_) => saved.future;
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('moments-reminder-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('moments-reminder-save')),
      );
      await tester.tap(find.byKey(const ValueKey('moments-reminder-save')));
      await tester.pump();
      owner = 'other';
      events.add(owner);
      await tester.pump();
      saved.complete(
        const MomentEngagement(
          reminder: MomentReminder(enabled: true),
          hasRecords: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('로그인 계정이 변경됐어요. 기록 화면에서 다시 열어 주세요.'), findsOneWidget);
      expect(find.text('선택한 시간에 주 1회 알려드릴게요.'), findsNothing);
    },
  );
  testWidgets(
    'small viewport and larger type remain scrollable without overflow',
    (tester) async {
      await mount(tester, width: 320, scale: 1.8);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('moments-reminder-save')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
