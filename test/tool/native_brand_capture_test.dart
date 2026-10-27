import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/attendance/domain/attendance_status.dart';
import 'package:snap_fit/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:snap_fit/features/attendance/presentation/views/attendance_screen.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';

import '../widget/ai_album_start_step_test.dart' show loadCreationFonts;

class _CaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _ImageClient extends Mock implements HttpClient {}

class _ImageRequest extends Mock implements HttpClientRequest {}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _author = SocialProfile(
  userId: 'local-brand-author',
  displayName: '서연의 사진 기록',
  handle: 'seoyeon.archive',
  bio: '평범한 날의 작은 순간을 모아요.',
);

final _works = [
  SocialWork(
    id: 'local-brand-jeju',
    author: _author,
    title: '바람이 머문 제주',
    caption: '사진 한 장에 담아 둔, 오래 기억하고 싶은 순간.',
    topic: '여행',
    imageUrls: const ['https://fixture.invalid/brand-jeju.jpg'],
    aspectRatio: 700 / 395,
    likeCount: 24,
    commentCount: 3,
    createdAt: DateTime.utc(2026, 10, 26),
  ),
];

final _attendance = AttendanceStatus(
  serverTime: DateTime.utc(2026, 10, 26, 3),
  serverDate: DateTime.utc(2026, 10, 26),
  timezone: 'Asia/Seoul',
  nextResetAt: DateTime.utc(2026, 10, 26, 15),
  checkedInToday: false,
  currentStreak: 2,
  cycleDay: 3,
  todayReward: 20,
  weeklyRewards: const [10, 10, 20, 10, 10, 10, 30],
  month: '2026-10',
  monthPoints: 20,
  monthAttendanceCount: 2,
  history: [
    AttendanceRecord(
      date: DateTime.utc(2026, 10, 24),
      points: 10,
      cycleDay: 1,
      streak: 1,
    ),
    AttendanceRecord(
      date: DateTime.utc(2026, 10, 25),
      points: 10,
      cycleDay: 2,
      streak: 2,
    ),
  ],
  claimed: false,
  awardedPoints: 0,
  balance: 340,
);

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  final render =
      boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('output/brand-cyan-20261026/native-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  _CaptureBinding();
  setUpAll(() => registerFallbackValue(Uri.parse('https://fixture.invalid')));
  testWidgets('capture actual native feed and attendance brand presentation', (
    tester,
  ) async {
    await loadCreationFonts();
    final photo = (await rootBundle.load(
      'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg',
    )).buffer.asUint8List();
    final client = _ImageClient();
    when(() => client.getUrl(any())).thenAnswer((_) async {
      final request = _ImageRequest();
      when(
        () => request.close(),
      ).thenAnswer((_) async => _ImageResponse(photo));
      return request;
    });
    final previous = painting.debugNetworkImageHttpClientProvider;
    painting.debugNetworkImageHttpClientProvider = () => client;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      for (final dark in [false, true]) {
        for (final screen in ['feed', 'attendance']) {
          final boundary = GlobalKey();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                socialCurrentUserIdProvider.overrideWithValue(
                  'local-brand-viewer',
                ),
                socialFeedProvider.overrideWith(
                  (ref, query) async => SocialWorkPage(
                    items: _works,
                    hasMore: false,
                    nextOffset: _works.length,
                  ),
                ),
                attendanceCurrentUserIdProvider.overrideWithValue(
                  'local-brand-viewer',
                ),
                attendanceStatusProvider.overrideWith(
                  (ref) async => _attendance,
                ),
              ],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, _) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
                  home: RepaintBoundary(
                    key: boundary,
                    child: screen == 'feed'
                        ? Scaffold(
                            body: const SocialFeedScreen(),
                            bottomNavigationBar: HomeBottomNavigationBar(
                              currentIndex: 7,
                              onTap: (_) {},
                            ),
                          )
                        : const AttendanceScreen(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          if (screen == 'feed') {
            await tester.runAsync(() async {
              for (final element in find.byType(Image).evaluate()) {
                await precacheImage((element.widget as Image).image, element);
              }
            });
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$screen dark=$dark');
          if (screen == 'attendance') {
            expect(
              find.byKey(const ValueKey('attendance-check-in')).hitTestable(),
              findsOneWidget,
            );
          } else {
            expect(find.byType(SocialFeedCard), findsOneWidget);
          }
          await _capture(
            tester,
            boundary,
            '$screen-${dark ? 'dark' : 'light'}',
          );
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      painting.debugNetworkImageHttpClientProvider = previous;
      painting.PaintingBinding.instance.imageCache.clear();
      painting.PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }, skip: !const bool.fromEnvironment('BRAND_CAPTURE'));
}
