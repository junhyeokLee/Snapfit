import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_publish_screen.dart';

class _Albums extends Mock implements AlbumRepository {}

class _Social extends Mock implements SocialRepository {}

class _Owner extends Notifier<String?> {
  @override
  String? build() => 'me';
  void change(String? value) => state = value;
}

final _owner = NotifierProvider<_Owner, String?>(_Owner.new);

const _profile = SocialProfile(
  userId: 'me',
  displayName: '공개 기록',
  handle: 'public.note',
);
final _saved = Album(
  id: 42,
  title: '내 저장된 앨범',
  userId: 'me',
  ratio: '1:1',
  updatedAt: '2026-10-26T00:00:00.000Z',
  coverLayersJson: jsonEncode({
    'pages': [
      {'index': 0, 'isCover': true, 'layers': []},
    ],
  }),
);

ProviderContainer _container(_Albums albums, _Social social) =>
    ProviderContainer(
      overrides: [
        socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_owner)),
        socialAuthStateProvider.overrideWith(
          (_) => const Stream<String?>.empty(),
        ),
        socialRepositoryProvider.overrideWithValue(social),
        albumRepositoryProvider.overrideWithValue(albums),
        socialPublishAlbumsProvider.overrideWith((_) async => [_saved]),
      ],
    );

void _beginResult(
  _Social repository,
  Future<SocialPublicationDraft> Function() result,
) {
  when(
    () => repository.beginPublication(
      albumId: any(named: 'albumId'),
      pageIndexes: any(named: 'pageIndexes'),
      title: any(named: 'title'),
      caption: any(named: 'caption'),
      topic: any(named: 'topic'),
      requestId: any(named: 'requestId'),
      expectedUpdatedAt: any(named: 'expectedUpdatedAt'),
      includeSourceTemplate: any(named: 'includeSourceTemplate'),
    ),
  ).thenAnswer((_) => result());
}

Future<void> _mount(WidgetTester tester, ProviderContainer container) async {
  addTearDown(container.dispose);
  await tester.binding.setSurfaceSize(const Size(600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SnapFitTheme.light().copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        home: SocialPublishScreen(album: _saved),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _review(WidgetTester tester) async {
  await _tap(tester, find.text('다음 · 1쪽'));
  await _tap(tester, find.text('다음 · 1쪽'));
  await _tap(tester, find.byType(CheckboxListTile));
  await _tap(tester, find.text('프로필에 앨범 공개'));
}

void main() {
  testWidgets('canceling a saved album reload discards its late response', (
    tester,
  ) async {
    final albums = _Albums();
    final social = _Social();
    final reload = Completer<Album>();
    var albumReads = 0;
    when(() => albums.fetchAlbum('42')).thenAnswer((_) async {
      if (albumReads++ == 0) return _saved;
      return reload.future;
    });
    when(() => social.ensureOwnProfile()).thenAnswer((_) async => _profile);
    _beginResult(social, () async => throw StateError('social_source_changed'));
    final container = _container(albums, social);
    await _mount(tester, container);
    await _review(tester);
    final reloadButton = find.text('저장된 앨범 다시 불러오기');
    expect(reloadButton, findsOneWidget);
    await tester.ensureVisible(reloadButton);
    await tester.tap(reloadButton);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('이전 단계'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3 · 앨범 소개'), findsOneWidget);
    reload.complete(_saved.copyWith(title: '늦게 도착한 이전 선택'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3 · 앨범 소개'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      _saved.title,
    );
    expect(find.text('늦게 도착한 이전 선택'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resolving a previous draft locks publishing until its result arrives',
    (tester) async {
      final albums = _Albums();
      final social = _Social();
      final discard = Completer<bool>();
      when(() => albums.fetchAlbum('42')).thenAnswer((_) async => _saved);
      when(() => social.ensureOwnProfile()).thenAnswer((_) async => _profile);
      _beginResult(
        social,
        () async => const SocialPublicationDraft(
          id: 'draft',
          pageIndexes: [0],
          status: 'published',
        ),
      );
      when(() => social.fetchWork('draft')).thenAnswer((_) async => null);
      when(
        () => social.discardPublication('draft'),
      ).thenAnswer((_) => discard.future);
      final container = _container(albums, social);
      await _mount(tester, container);
      await _review(tester);
      await _tap(tester, find.text('이전 단계에서 다시 확인'));
      expect(find.text('공개 내용을 다시 확인할까요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '다시 확인'));
      await tester.pumpAndSettle();
      final publish = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '앨범 공개 중…'),
      );
      expect(publish.onPressed, isNull);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '이전 단계',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      verify(() => social.ensureOwnProfile()).called(1);
      verify(() => social.discardPublication('draft')).called(1);
      discard.complete(false);
      await tester.pumpAndSettle();
      // An inconclusive result retains the original draft and consent for retry.
      expect(find.text('3 / 3 · 최종 확인'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await _tap(tester, find.text('이전 단계에서 다시 확인'));
      expect(find.text('공개 내용을 다시 확인할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final unfinished in [false, true]) {
    testWidgets(
      'account changes dismiss ${unfinished ? 'unfinished cleanup' : 'draft review'} confirmation',
      (tester) async {
        final albums = _Albums();
        final social = _Social();
        when(() => albums.fetchAlbum('42')).thenAnswer((_) async => _saved);
        when(() => social.ensureOwnProfile()).thenAnswer((_) async => _profile);
        if (unfinished) {
          _beginResult(
            social,
            () async => throw StateError('social_draft_limit'),
          );
        } else {
          _beginResult(
            social,
            () async => const SocialPublicationDraft(
              id: 'draft',
              pageIndexes: [0],
              status: 'published',
            ),
          );
          when(() => social.fetchWork('draft')).thenAnswer((_) async => null);
        }
        final container = _container(albums, social);
        await _mount(tester, container);
        await _review(tester);
        await _tap(
          tester,
          find.text(unfinished ? '미완료 공개 정리' : '이전 단계에서 다시 확인'),
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        container.read(_owner.notifier).change('second-account');
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        container.read(_owner.notifier).change('me');
        await tester.pumpAndSettle();
        expect(find.text('계정이 변경됐어요.'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
        verifyNever(() => social.discardPublication(any()));
        verifyNever(() => social.discardUnfinishedPublications());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a non-owned fresh album cannot enter the publication form', (
    tester,
  ) async {
    final albums = _Albums();
    final social = _Social();
    when(() => albums.fetchAlbum('42')).thenAnswer(
      (_) async =>
          _saved.copyWith(userId: 'another-owner', memberRole: 'EDITOR'),
    );
    final container = _container(albums, social);
    await _mount(tester, container);
    expect(find.text('앨범 소유자만 앨범을 공개할 수 있어요.'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('어떤 장면을 나눌까요?'), findsNothing);
    verifyNever(() => social.ensureOwnProfile());
    expect(tester.takeException(), isNull);
  });
}
