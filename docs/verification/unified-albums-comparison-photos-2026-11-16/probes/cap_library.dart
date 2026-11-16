// 전체·즐겨찾기의 실제 앨범 목록과 제목·별 위치를 현재 위젯으로 재현한다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/views/album_category_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_helpers.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

import 'file:///tmp/snapfit-ux-applied-20261116/audit_support.dart';

Album _album(int id, String title, {required bool completed}) => Album(
  id: id,
  userId: 'qa',
  title: title,
  ratio: '1',
  coverTheme: 'classic',
  targetPages: 2,
  totalPages: 3,
  createdAt: '2026-11-${(15 - id).toString().padLeft(2, '0')}T10:00:00',
  coverLayersJson: jsonEncode({
    'pages': [
      {
        'index': 0,
        'isCover': true,
        'backgroundColor': 0xfff3f6f5,
        'layers': [
          {
            'id': 'library-cover-$id',
            'type': 'IMAGE',
            'x': 0.0,
            'y': 0.0,
            'width': 1.0,
            'height': 1.0,
            'rotation': 0.0,
            'payload': {
              'originalUrl': id.isOdd
                  ? 'asset:assets/snapfit_home_square.jpg'
                  : 'asset:assets/snapfit_home_landscape.jpg',
            },
            'zIndex': 0,
          },
        ],
      },
      for (var page = 1; page <= 2; page++)
        {
          'index': page,
          'isCover': false,
          'layers': completed || page == 1
              ? [
                  {
                    'id': 'library-entry-$id-$page',
                    'type': 'TEXT',
                    // 실제 작성한 내지라는 기존 완료 판정 규칙을 충족한다.
                    'templateContent': false,
                    'payload': {'text': '직접 남긴 우리 여행의 기록 $page'},
                  },
                ]
              : [],
        },
    ],
  }),
);

Future<void> _mount(
  WidgetTester tester,
  List<Album> albums, {
  Size size = const Size(390, 844),
  bool dark = false,
  double scale = 1,
}) async {
  auditViewport(tester, size: size);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    auditFrame(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [albumCollaborationActorProvider.overrideWithValue('qa')],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: AlbumCategoryScreen(
              category: AlbumCategory.recent,
              initialAlbums: albums,
              currentUserId: 'qa',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _title = '함께 걸었던 가을 여행의 오래 남을 장면들';

Finder _record(int id) => find.byKey(ValueKey('personal-record-$id'));
Finder _favorite(int id) =>
    find.descendant(of: _record(id), matching: find.byTooltip('즐겨찾기'));

List<Album> _mixed() => [
  _album(1, _title, completed: true),
  _album(2, '아직 만드는 중인 겨울 이야기', completed: false),
];

void _expectUnifiedTabs() {
  expect(find.text('전체'), findsOneWidget);
  expect(find.text('즐겨찾기'), findsOneWidget);
  expect(find.text('진행 중'), findsNothing);
  expect(find.text('완료'), findsNothing);
}

void _expectTitleSpace(WidgetTester tester) {
  final title = find.descendant(of: _record(1), matching: find.text(_title));
  final star = _favorite(1);
  // 제목이 별 버튼 폭을 계속 빼앗기지 않고, 두 조작 영역도 겹치지 않는다.
  expect(
    tester.getSize(title).width,
    greaterThan(
      tester.getSize(_record(1)).width - tester.getSize(star).width + 4,
    ),
  );
  expect(tester.getRect(title).overlaps(tester.getRect(star)), isFalse);
  expect(tester.getSize(star).width, greaterThanOrEqualTo(44));
  expect(tester.getSize(star).height, greaterThanOrEqualTo(44));
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(auditFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'capture unified library default contains completed and working albums',
    (tester) async {
      final mixed = _mixed();
      expect(isCompletedAlbum(mixed[0]), isTrue);
      expect(isCompletedAlbum(mixed[1]), isFalse);
      await _mount(tester, mixed);
      _expectUnifiedTabs();
      expect(_record(1), findsOneWidget);
      expect(_record(2), findsOneWidget);
      expect(find.text('표시할 앨범이 없습니다.'), findsNothing);
      _expectTitleSpace(tester);
      await auditCapture(tester, '01-library-all-mixed-390-light');
      await _finish(tester);
    },
  );

  testWidgets('capture unified library favorites preserves selected album', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'album_favorite_ids_v1': ['1'],
    });
    await _mount(tester, _mixed());
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    _expectUnifiedTabs();
    expect(_record(1), findsOneWidget);
    expect(_record(2), findsNothing);
    expect(find.byTooltip('즐겨찾기 해제'), findsOneWidget);
    await auditCapture(tester, '02-library-favorites-390-light');
    await _finish(tester);
  });

  testWidgets('capture unified library small dark accessible titles', (
    tester,
  ) async {
    await _mount(
      tester,
      _mixed(),
      size: const Size(320, 568),
      dark: true,
      scale: 1.8,
    );
    _expectUnifiedTabs();
    expect(_favorite(1).hitTestable(), findsOneWidget);
    await auditCapture(tester, '03-library-320-dark-text180');
    final title = find.descendant(of: _record(1), matching: find.text(_title));
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    _expectTitleSpace(tester);
    await auditCapture(tester, '04-library-title-320-dark-text180');
    await _finish(tester);
  });

  testWidgets('capture unified library landscape accessible titles', (
    tester,
  ) async {
    await _mount(
      tester,
      _mixed(),
      size: const Size(844, 390),
      dark: true,
      scale: 1.8,
    );
    _expectUnifiedTabs();
    final title = find.descendant(of: _record(1), matching: find.text(_title));
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    _expectTitleSpace(tester);
    expect(title.hitTestable(), findsOneWidget);
    await auditCapture(tester, '05-library-landscape-844-dark-text180');
    await _finish(tester);
  });
}
