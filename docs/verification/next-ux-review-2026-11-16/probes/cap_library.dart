// 완성된 앨범이 기본 탭에서 보이지 않는 상태만 실제 화면으로 재현한다.
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

import 'audit_support.dart';

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
            'payload': {'originalUrl': 'asset:assets/snapfit_home_square.jpg'},
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

Future<void> _mount(WidgetTester tester, List<Album> albums) async {
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
            theme: SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.noScaling),
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

void main() {
  setUpAll(auditFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('capture album collection default and completed states', (
    tester,
  ) async {
    auditViewport(tester);
    final finished = [
      _album(1, '함께 걸었던 가을 여행', completed: true),
      _album(2, '우리의 두 번째 여름', completed: true),
    ];
    expect(finished.every(isCompletedAlbum), isTrue);

    await _mount(tester, finished);
    expect(find.text('표시할 앨범이 없습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('personal-record-1')), findsNothing);
    await auditCapture(tester, '01-library-default-completed-only');

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(find.text('표시할 앨범이 없습니다.'), findsNothing);
    expect(find.byKey(const ValueKey('personal-record-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('personal-record-2')), findsOneWidget);
    await auditCapture(tester, '02-library-completed-tab');

    final working = _album(3, '만드는 중인 겨울 이야기', completed: false);
    expect(isCompletedAlbum(working), isFalse);
    await _mount(tester, [...finished, working]);
    expect(find.byKey(const ValueKey('personal-record-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('personal-record-1')), findsNothing);
    await auditCapture(tester, '03-library-default-mixed');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
