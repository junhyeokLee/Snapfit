// Opt-in, local-only exports of production journal widgets.
// flutter test test/tool/personal_journal_ux_export_test.dart \
//   --dart-define=EXPORT_PERSONAL_JOURNAL_UX=true
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_engagement_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/private_moment_archive_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/monthly_moment_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/weekly_moment_recap_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_month_calendar.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/features/moments/presentation/widgets/web_moments_journal_layout.dart';
import 'package:snap_fit/shared/snapfit_image.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';

import '../helpers/memory_moment_draft_store.dart';

const _export = bool.fromEnvironment('EXPORT_PERSONAL_JOURNAL_UX');
const _folder = String.fromEnvironment(
  'PERSONAL_JOURNAL_UX_OUTPUT',
  defaultValue: 'output/personal-journal-20261030/ui',
);
const _owner = 'isolated-journal-preview';
final _month = DateTime.utc(2026, 10);
final _today = DateTime.utc(2026, 10, 30);
final _week = DateTime.utc(2026, 10, 26);

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Photo extends MomentPhoto {
  _Photo(String id, String asset, int width, int height)
    : super(
        id: id,
        path: '$_owner/moments/$id.jpg',
        url: 'asset:$asset',
        width: width,
        height: height,
      );
  @override
  String get storageUri => url;
}

final _records = <MomentRecord>[
  for (final entry in [
    (
      30,
      'assets/templates/atelier_editions_2026/alley-afternoon.png',
      1254,
      1254,
      '골목에서 만난 오후의 빛. 천천히 걸어도 좋았던 날.',
    ),
    (
      28,
      'assets/frame_preview/ocean_shore.jpg',
      1000,
      665,
      '바다를 보고 돌아오는 길에는 마음도 조금 가벼워졌다.',
    ),
    (
      26,
      'assets/frame_preview/forest_trail.jpg',
      1000,
      667,
      '바람 소리를 들으며 걸었다. 오늘은 이 장면을 오래 기억하고 싶다.',
    ),
    (22, 'assets/frame_preview/alpine_lake.jpg', 1000, 667, '잠시 멈춰 바라본 풍경.'),
    (
      18,
      'assets/frame_preview/spring_flowers.jpg',
      1000,
      667,
      '집으로 돌아가는 길에 작은 꽃을 발견했다.',
    ),
    (
      15,
      'assets/frame_preview/quiet_room.jpg',
      1000,
      668,
      '아무 일정 없이 보낸 조용한 하루.',
    ),
    (12, 'assets/frame_preview/ocean_shore.jpg', 1000, 665, '다음에도 다시 오고 싶은 곳.'),
    (
      8,
      'assets/frame_preview/forest_trail.jpg',
      1000,
      667,
      '걷다가 멈추고, 사진을 한 장 남겼다.',
    ),
    (
      5,
      'assets/frame_preview/spring_flowers.jpg',
      1000,
      667,
      '평범한 날도 모아두면 한 권이 된다.',
    ),
    (2, 'assets/frame_preview/alpine_lake.jpg', 1000, 667, '이번 달의 첫 장면.'),
  ])
    MomentRecord(
      id: 'scene-${entry.$1}',
      recordDate: DateTime.utc(2026, 10, entry.$1),
      caption: entry.$5,
      revision: 1,
      photos: [_Photo('photo-${entry.$1}', entry.$2, entry.$3, entry.$4)],
    ),
];

class _Moments implements MomentsRepository {
  int mutations = 0;
  @override
  String get currentUserId => _owner;
  @override
  Stream<String?> get authChanges => Stream.value(_owner);
  @override
  Future<MomentJournal> listMonth(DateTime? month) async => MomentJournal(
    today: _today,
    weekStart: _week,
    month: month ?? momentMonth(_today),
    records: _records,
    weekRecords: _records
        .where((record) => !record.recordDate.isBefore(_week))
        .toList(),
    weekPhotoCount: 3,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) {
    mutations++;
    throw StateError(
      'Preview must not mutate records or albums: ${invocation.memberName}',
    );
  }
}

class _Archive implements PrivateMomentArchiveRepository {
  int writes = 0;
  @override
  String get currentUserId => _owner;
  @override
  int get sessionRevision => 0;
  @override
  Stream<int> get sessionChanges => const Stream.empty();
  @override
  Future<List<MomentMonthSummary>> listMonths({
    required String ownerId,
    DateTime? beforeMonth,
    int limit = 6,
  }) async => [];
  @override
  Future<List<String>> weeklyPhotoChoices({
    required String ownerId,
    required DateTime weekStart,
  }) async => [];
  @override
  Future<List<String>> monthlyPhotoChoices({
    required String ownerId,
    required DateTime month,
  }) async => ['photo-30', 'photo-26'];
  @override
  Future<void> saveWeeklyPhotoChoices({
    required String ownerId,
    required DateTime weekStart,
    required List<String> photoIds,
  }) async {
    writes++;
    throw StateError(
      'Exports only read and select; the save button must not be pressed',
    );
  }
}

class _Engagement implements MomentEngagementRepository {
  @override
  Future<MomentEngagement> load() async =>
      const MomentEngagement(reminder: MomentReminder(), hasRecords: true);
  @override
  Future<bool> recordActivity(
    MomentActivity activity, {
    DateTime? month,
  }) async => false;
  @override
  Future<MomentEngagement> saveReminder(MomentReminder reminder) =>
      throw StateError('Exports cannot change reminder preferences');
}

Future<void> _fonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in entry['fonts'] as List)
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    await loader.load();
  }
}

Future<void> _images(WidgetTester tester) async {
  for (var pass = 0; pass < 3; pass++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      for (final widget in tester.widgetList<SnapfitImage>(
        find.byType(SnapfitImage),
      )) {
        for (final source in [widget.urlOrGs, ...widget.fallbackSources]) {
          if (!source.startsWith('asset:')) continue;
          await precacheImage(
            ResizeImage.resizeIfNeeded(
              widget.memCacheWidth,
              widget.memCacheHeight,
              AssetImage(source.substring(6)),
            ),
            context,
          ).timeout(const Duration(seconds: 10));
        }
      }
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage(
          (element.widget as Image).image,
          element,
        ).timeout(const Duration(seconds: 10));
      }
    });
  }
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await _images(tester);
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_folder/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}

/// The desktop export mounts the same responsive production layout component
/// explicitly because native widget tests cannot change the kIsWeb constant.
/// The mobile export below mounts the entire actual MomentsScreen route.
class _DesktopJournal extends StatelessWidget {
  const _DesktopJournal({required this.calendar});
  final bool calendar;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ExperienceHeader(title: '나의 기록', showNotifications: false),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            const WebPageHeading(
              title: '나의 기록',
              description: '사진 한 장과 짧은 한 줄, 하루씩 쌓이는 나의 기록.',
            ),
            const SizedBox(height: 18),
            WebMomentsJournalLayout(
              monthNavigation: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '2026년 10월',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        tooltip: '이번 주 돌아보기',
                        icon: const Icon(Icons.auto_awesome_motion_outlined),
                      ),
                      IconButton(
                        onPressed: () {},
                        tooltip: '월간 앨범 만들기',
                        icon: const Icon(Icons.auto_stories_outlined),
                      ),
                      IconButton(
                        onPressed: () {},
                        tooltip: '이전 달',
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        onPressed: null,
                        tooltip: '다음 달',
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  if (calendar)
                    MomentMonthCalendar(
                      month: _month,
                      records: _records,
                      onDateSelected: (_) {},
                    ),
                ],
              ),
              weekly: MomentWeekCard(photoCount: 3, onRecord: () {}),
              records: [
                for (final record in _records)
                  MomentRecordCard(
                    record: record,
                    onEdit: () {},
                    maxPhotoHeight: 500,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  _PaintBinding();
  setUpAll(() async {
    if (_export) await _fonts();
  });
  for (final desktop in [false, true]) {
    for (final kind in ['journal', 'calendar', 'weekly', 'monthly']) {
      final name = '${desktop ? 'desktop' : 'mobile'}-$kind';
      testWidgets(
        'export $name with actual bundled photos and original fonts',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = desktop
              ? const Size(1440, 1000)
              : const Size(390, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final moments = _Moments();
          final archive = _Archive();
          final key = GlobalKey();
          final Widget screen = switch (kind) {
            'weekly' => WeeklyMomentRecapScreen(
              today: _today,
              weekStart: _week,
              records: _records,
              ownerUserId: _owner,
            ),
            'monthly' => MonthlyMomentPreviewScreen(
              month: _month,
              records: _records,
              today: _today,
            ),
            _ =>
              desktop
                  ? _DesktopJournal(calendar: kind == 'calendar')
                  : MomentsScreen(initialMonth: _month),
          };
          final container = ProviderContainer(
            overrides: [
              momentsRepositoryProvider.overrideWithValue(moments),
              privateMomentArchiveRepositoryProvider.overrideWithValue(archive),
              momentDraftStoreProvider.overrideWithValue(
                MemoryMomentDraftStore(),
              ),
              momentEngagementRepositoryProvider.overrideWithValue(
                _Engagement(),
              ),
            ],
          );
          try {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: SnapFitTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: RepaintBoundary(key: key, child: child!),
                  ),
                  home: screen,
                ),
              ),
            );
            await _images(tester);
            if (kind == 'calendar' && !desktop) {
              await tester.drag(
                find.byType(ListView).first,
                const Offset(0, -72),
              );
              await tester.pumpAndSettle();
            } else if (kind == 'weekly') {
              await tester.tap(
                find.byKey(const ValueKey('weekly-photo-choice-photo-26')),
              );
              await tester.tap(find.byTooltip('다음 돌아보기 사진'));
              await _images(tester);
              await tester.tap(
                find.byKey(const ValueKey('weekly-photo-choice-photo-28')),
              );
              await tester.pumpAndSettle();
              expect(find.text('이번 주 후보 2 / 3'), findsOneWidget);
            } else if (kind == 'monthly') {
              final scrollable = find
                  .descendant(
                    of: find.byType(ListView).first,
                    matching: find.byType(Scrollable),
                  )
                  .first;
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('monthly-moment-preview')),
                250,
                scrollable: scrollable,
                maxScrolls: 12,
              );
            }
            await _capture(tester, key, name);
            expect(moments.mutations, 0);
            expect(archive.writes, 0);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            container.dispose();
          }
        },
        skip: !_export,
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
