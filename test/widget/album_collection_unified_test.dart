import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/views/album_category_screen.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

// 실제 작성 provenance를 포함하므로 할당된 쪽수만으로 완료를 흉내 내지 않는다.
Album _album(
  int id,
  String title, {
  required bool completed,
  String owner = 'qa',
}) => Album(
  id: id,
  userId: owner,
  title: title,
  coverTheme: 'classic',
  ratio: '1',
  totalPages: 3,
  targetPages: 2,
  createdAt: '2026-11-${(15 - id).toString().padLeft(2, '0')}T10:00:00',
  coverLayersJson: jsonEncode({
    'pages': [
      {'index': 0, 'isCover': true, 'layers': []},
      for (var index = 1; index <= 2; index++)
        {
          'index': index,
          'isCover': false,
          'layers': completed || index == 1
              ? [
                  {
                    'type': 'TEXT',
                    'templateContent': false,
                    'payload': {'text': '직접 남긴 기록 $index'},
                  },
                ]
              : [],
        },
    ],
  }),
);

class _Actor extends Notifier<String?> {
  @override
  String? build() => 'qa';

  void change(String? owner) => state = owner;
}

final _actorProvider = NotifierProvider<_Actor, String?>(_Actor.new);

Finder _record(int id) => find.byKey(ValueKey('personal-record-$id'));

Future<ProviderContainer> _mount(
  WidgetTester tester,
  List<Album> albums, {
  AlbumCategory category = AlbumCategory.recent,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      // SDK 세션 대신 화면이 실제로 구독하는 계정 경계만 제어한다.
      albumCollaborationActorProvider.overrideWith(
        (ref) => ref.watch(_actorProvider),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: AlbumCategoryScreen(
            category: category,
            initialAlbums: albums,
            currentUserId: 'qa',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'album collection first entry keeps completed and working albums together',
    (tester) async {
      await _mount(tester, [
        _album(1, '완성한 가을 여행', completed: true),
        _album(2, '만드는 중인 겨울 여행', completed: false),
      ]);

      expect(_record(1), findsOneWidget);
      expect(_record(2), findsOneWidget);
      expect(find.text('전체'), findsOneWidget);
      expect(find.text('진행 중'), findsNothing);
      expect(find.text('완료'), findsNothing);
      expect(find.text('표시할 앨범이 없습니다.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'album search includes both states and respects the favorites scope',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'album_favorite_ids_v1': ['1', '3'],
      });
      await _mount(tester, [
        _album(1, '가을 여행 완성본', completed: true),
        _album(2, '가을 여행 초안', completed: false),
        _album(3, '봄 소풍 완성본', completed: true),
      ]);
      await tester.tap(find.byTooltip('앨범 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '가을 여행');
      await tester.pumpAndSettle();
      expect(_record(1), findsOneWidget);
      expect(_record(2), findsOneWidget);
      expect(_record(3), findsNothing);

      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(_record(1), findsOneWidget);
      expect(_record(2), findsNothing);
      await tester.enterText(find.byType(TextField), '봄');
      await tester.pumpAndSettle();
      expect(_record(3), findsOneWidget);
      expect(_record(1), findsNothing);

      await tester.enterText(find.byType(TextField), '가을 여행');
      await tester.tap(find.text('전체'));
      await tester.pumpAndSettle();
      expect(_record(1), findsOneWidget);
      expect(_record(2), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shared collection keeps its ownership and session boundaries', (
    tester,
  ) async {
    final container = await _mount(tester, [
      _album(1, '내가 만든 앨범', completed: true),
      _album(2, '함께 만드는 앨범', completed: false, owner: 'friend'),
      _album(3, '함께 완성한 앨범', completed: true, owner: 'friend'),
      _album(4, '소유자 미확인', completed: false, owner: ''),
    ], category: AlbumCategory.shared);

    expect(_record(1), findsNothing);
    expect(_record(2), findsOneWidget);
    expect(_record(3), findsOneWidget);
    expect(_record(4), findsNothing);
    container.read(_actorProvider.notifier).change('other-account');
    await tester.pumpAndSettle();
    expect(_record(2), findsNothing);
    expect(_record(3), findsNothing);
    expect(find.textContaining('계정이 변경되었어요.'), findsOneWidget);
    expect(find.byTooltip('앨범 검색'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(844, 390), 1.0),
    (const Size(390, 844), 1.8),
  ]) {
    testWidgets('album collection stays usable at $size textScale=$scale', (
      tester,
    ) async {
      await _mount(
        tester,
        [
          _album(1, '함께 남긴 긴 제목의 여행 기록을 다시 찾아보는 앨범', completed: true),
          _album(2, '만드는 중인 두 번째 이야기', completed: false),
        ],
        size: size,
        textScale: scale,
      );
      expect(_record(1), findsOneWidget);
      expect(find.text('전체').hitTestable(), findsOneWidget);
      final favorite = find.descendant(
        of: _record(1),
        matching: find.byTooltip('즐겨찾기'),
      );
      await tester.ensureVisible(favorite);
      await tester.pumpAndSettle();
      expect(favorite.hitTestable(), findsOneWidget);
      expect(tester.getSize(favorite).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(favorite).height, greaterThanOrEqualTo(44));
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _record(1), matching: find.byTooltip('즐겨찾기 해제')),
        findsOneWidget,
      );
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'album_favorite_ids_v1',
        ),
        ['1'],
      );
      expect(
        ModalRoute.of(
          tester.element(find.byType(AlbumCategoryScreen)),
        )?.isCurrent,
        isTrue,
        reason: '즐겨찾기는 부모 카드의 앨범 열기를 실행하면 안 된다.',
      );
      // 표지를 드러내며 화면 밖으로 밀린 탭도 찾아 스크롤을 되돌린다.
      // 제스처 새로고침 없이 돌아가므로 저장소 요청을 만들지 않는다.
      await tester.ensureVisible(find.text('즐겨찾기', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(_record(1), findsOneWidget);
      expect(_record(2), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
