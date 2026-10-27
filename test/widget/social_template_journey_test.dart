import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_publish_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_template_start_card.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/repositories/template_repository.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/store_detail_loading.dart';

const _profile = SocialProfile(
  userId: 'me',
  displayName: '나의 작품',
  handle: 'my.photos',
);
const _source = SocialTemplateSource(
  productKey: 'template:server-987654',
  title: '내 기록을 담는 디자인',
);
final _template = PremiumTemplate(
  id: 987654,
  title: _source.title,
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 20,
  userCount: 0,
  isPremium: true,
  templateJson: jsonEncode({
    'designWidth': 500,
    'designHeight': 500,
    'pages': [
      {'layers': <Object>[]},
    ],
  }),
);

SocialWork _work({
  String id = 'work',
  SocialTemplateSource? source = _source,
  String status = 'published',
}) => SocialWork(
  id: id,
  author: _profile,
  title: '사진으로 남긴 여름',
  createdAt: DateTime(2026, 10, 26),
  sourceTemplate: source,
  status: status,
);

Album _album({bool source = true, String owner = 'me'}) => Album(
  id: 42,
  title: '저장한 내 앨범',
  userId: owner,
  ratio: '1:1',
  updatedAt: '2026-10-26T00:00:00.000Z',
  coverLayersJson: jsonEncode({
    if (source) 'sourceTemplate': {'productKey': _source.productKey},
    'pages': [
      {'index': 0, 'isCover': true, 'layers': []},
    ],
  }),
);

class _Actor extends Notifier<String?> {
  @override
  String? build() => 'me';
  void change(String? value) => state = value;
}

final _actor = NotifierProvider<_Actor, String?>(_Actor.new);

class _Auth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'me', name: '사용자', provider: 'email');
}

class _DraftStore extends Fake implements AlbumCreationDraftStore {
  @override
  Future<AlbumCreationDraft?> load(String owner) async => null;
}

class _Albums extends Fake implements AlbumRepository {
  _Albums(this.album);
  Album album;
  int reads = 0;
  @override
  Future<Album> fetchAlbum(String id) async {
    reads++;
    return album;
  }

  @override
  Future<List<Album>> fetchMyAlbums() async => [album];
}

class _Templates extends Fake implements TemplateRepository {
  @override
  Future<PremiumTemplate> getTemplate(int id) async => _template;
}

class _Social extends SocialRepository {
  _Social()
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'test-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final works = <String, SocialWork>{'work': _work()};
  SocialTemplateSource? resolved = _source;
  SocialTemplateSource? albumSource = _source;
  Completer<SocialTemplateSource?>? pendingResolve;
  Completer<SocialTemplateSource?>? pendingAlbumSource;
  bool failResolve = false, failAlbumSource = false;
  final resolveCalls = <String>[];
  final sourceCalls = <int>[];
  final beginCalls =
      <
        ({
          String? requestId,
          bool includeSourceTemplate,
          String title,
          String caption,
        })
      >[];
  @override
  Future<SocialWork?> fetchWork(String id) async => works[id];
  @override
  Future<SocialCommentPage> fetchCommentsPage(
    String id, {
    int offset = 0,
    int limit = 12,
  }) async => const SocialCommentPage(items: [], hasMore: false, nextOffset: 0);
  @override
  Future<SocialTemplateSource?> resolveWorkTemplate(String workId) async {
    resolveCalls.add(workId);
    if (failResolve)
      throw const SocketException('Synthetic catalog unavailable');
    return pendingResolve?.future ?? resolved;
  }

  @override
  Future<SocialTemplateSource?> fetchAlbumTemplateSource(int albumId) async {
    sourceCalls.add(albumId);
    if (failAlbumSource)
      throw const SocketException('Synthetic source lookup failure');
    return pendingAlbumSource?.future ?? albumSource;
  }

  @override
  Future<SocialProfile> ensureOwnProfile() async => _profile;
  @override
  Future<SocialPublicationDraft> beginPublication({
    required int albumId,
    required List<int> pageIndexes,
    required String title,
    String caption = '',
    String topic = '일상',
    String? requestId,
    String? expectedUpdatedAt,
    bool includeSourceTemplate = false,
  }) async {
    beginCalls.add((
      requestId: requestId,
      includeSourceTemplate: includeSourceTemplate,
      title: title,
      caption: caption,
    ));
    // An uncertain response must retain the same request and explicit consent.
    throw const SocketException('Synthetic lost begin response');
  }
}

ProviderContainer _container(
  _Social social, {
  Album? album,
  List<String>? gateCalls,
}) {
  final saved = album ?? _album();
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_actor)),
      socialAuthStateProvider.overrideWith(
        (_) => const Stream<String?>.empty(),
      ),
      socialRepositoryProvider.overrideWithValue(social),
      albumRepositoryProvider.overrideWithValue(_Albums(saved)),
      albumCreationCatalogProvider.overrideWith(
        (_) => Stream.value([_template]),
      ),
      albumCreationDraftStoreProvider.overrideWithValue(_DraftStore()),
      authViewModelProvider.overrideWith(_Auth.new),
      templateRepositoryProvider.overrideWithValue(_Templates()),
      pointShopCatalogProvider.overrideWith(
        (_) async => [
          PointShopProduct(
            productKey: _source.productKey,
            kind: 'template',
            assetId: '${_template.id}',
            title: _template.title,
            pointPrice: 900,
            isActive: true,
          ),
        ],
      ),
      ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
      pointShopAccessGateProvider.overrideWithValue((
        context,
        ref, {
        required productKey,
        required title,
      }) async {
        gateCalls?.add(productKey);
        return false;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _mount(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
) async {
  await tester.binding.setSurfaceSize(const Size(600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: SnapFitTheme.light().copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool pending = false,
}) async {
  await tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 35,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  if (pending) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> _description(WidgetTester tester) =>
    _tap(tester, find.text('다음 · 1쪽'));
Future<void> _publish(WidgetTester tester) async {
  await _tap(tester, find.text('다음 · 1쪽'));
  await _tap(tester, find.byType(CheckboxListTile));
  await _tap(tester, find.text('피드에 무료로 공개'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final state in ['legacy', 'private', 'unknown']) {
    testWidgets('$state work never offers an unavailable template entry', (
      tester,
    ) async {
      final social = _Social()
        ..works['work'] = _work(
          source: state == 'legacy'
              ? null
              : state == 'unknown'
              ? const SocialTemplateSource(
                  productKey: 'template:unknown-product',
                  title: '이름이 같은 디자인',
                )
              : _source,
          status: state == 'private' ? 'withdrawn' : 'published',
        );
      await _mount(
        tester,
        _container(social),
        const SocialWorkDetailScreen(workId: 'work'),
      );
      expect(find.byType(SocialTemplateStartCard), findsNothing);
      expect(social.resolveCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a withdrawn fresh source prevents navigation and a lookup failure can retry',
    (tester) async {
      final social = _Social()..failResolve = true;
      await _mount(
        tester,
        _container(social),
        const SocialWorkDetailScreen(workId: 'work'),
      );
      final button = find.byKey(const ValueKey('social-template-start-button'));
      expect(button, findsOneWidget);
      await _tap(tester, button);
      expect(find.byType(TemplateDetailScreen), findsNothing);
      social
        ..failResolve = false
        ..resolved = null;
      await _tap(tester, button);
      expect(social.resolveCalls, ['work', 'work']);
      expect(find.byType(TemplateDetailScreen), findsNothing);
      expect(find.text('지금은 이 작품의 템플릿을 이용할 수 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in ['account', 'source', 'withdrawal', 'work']) {
    testWidgets(
      'late template lookup after $change never navigates to stale content',
      (tester) async {
        final pending = Completer<SocialTemplateSource?>();
        final social = _Social()..pendingResolve = pending;
        final container = _container(social);
        final workId = ValueNotifier('work');
        addTearDown(workId.dispose);
        await _mount(
          tester,
          container,
          ValueListenableBuilder<String>(
            valueListenable: workId,
            builder: (_, id, __) => SocialWorkDetailScreen(workId: id),
          ),
        );
        await _tap(
          tester,
          find.byKey(const ValueKey('social-template-start-button')),
          pending: true,
        );
        if (change == 'account') {
          container.read(_actor.notifier).change('another-user');
        } else if (change == 'work') {
          social.works['next'] = _work(id: 'next', source: null);
          workId.value = 'next';
        } else {
          social.works['work'] = _work(
            source: change == 'source' ? null : _source,
            status: change == 'withdrawal' ? 'withdrawn' : 'published',
          );
          container.invalidate(socialWorkProvider('work'));
        }
        await tester.pump();
        await tester.pump();
        pending.complete(_source);
        await tester.pumpAndSettle();
        expect(find.byType(TemplateDetailScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  storeDetailTestWidgets(
    'a validated source opens its exact catalog design and retains the purchase gate',
    (tester) async {
      final gateCalls = <String>[];
      final social = _Social();
      await _mount(
        tester,
        _container(social, gateCalls: gateCalls),
        const SocialWorkDetailScreen(workId: 'work'),
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('social-template-start-button')),
        pending: true,
      );
      await settleStoreDetail(tester);
      final detail = tester.widget<TemplateDetailScreen>(
        find.byType(TemplateDetailScreen),
      );
      expect(pointShopTemplateKey(detail.template), _source.productKey);
      expect(gateCalls, isEmpty);
      await _tap(
        tester,
        find.byKey(const ValueKey('template-detail-use')),
        pending: true,
      );
      await settleStoreDetail(tester);
      expect(gateCalls, [_source.productKey]);
      expect(find.byType(AlbumCreateFlowScreen), findsNothing);
      expect(find.byType(TemplateDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final include in [false, true]) {
    testWidgets(
      'publication source opt-in $include stays explicit across uncertain retries',
      (tester) async {
        final social = _Social();
        final album = _album();
        await _mount(
          tester,
          _container(social, album: album),
          SocialPublishScreen(album: album),
        );
        await _description(tester);
        final consent = find.byKey(
          const ValueKey('social-publish-template-consent'),
        );
        expect(tester.widget<CheckboxListTile>(consent).value, isFalse);
        if (include) await _tap(tester, consent);
        await _publish(tester);
        expect(social.sourceCalls, [42]);
        expect(social.beginCalls, hasLength(1));
        expect(social.beginCalls.single.includeSourceTemplate, include);
        expect(
          find.byKey(const ValueKey('social-publish-template-review')),
          include ? findsOneWidget : findsNothing,
        );
        await _tap(tester, find.text('피드에 무료로 공개'));
        expect(social.beginCalls, hasLength(2));
        expect(
          social.beginCalls.last.requestId,
          social.beginCalls.first.requestId,
        );
        expect(social.beginCalls.last.includeSourceTemplate, include);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final reason in ['legacy', 'unverified', 'not-owner']) {
    testWidgets('$reason album cannot offer an unvalidated source opt-in', (
      tester,
    ) async {
      final album = _album(
        source: reason != 'legacy',
        owner: reason == 'not-owner' ? 'someone-else' : 'me',
      );
      final social = _Social()..albumSource = null;
      await _mount(
        tester,
        _container(social, album: album),
        SocialPublishScreen(album: album),
      );
      if (reason != 'not-owner') await _description(tester);
      expect(
        find.byKey(const ValueKey('social-publish-template-consent')),
        findsNothing,
      );
      expect(social.sourceCalls, reason == 'unverified' ? [42] : isEmpty);
      expect(social.beginCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'source retry preserves the description and selected pages without reloading the album',
    (tester) async {
      final social = _Social()..failAlbumSource = true;
      final album = _album();
      final container = _container(social, album: album);
      await _mount(tester, container, SocialPublishScreen(album: album));
      await _description(tester);
      await tester.enterText(find.byType(TextField).first, '내가 고친 작품 제목');
      await tester.enterText(find.byType(TextField).last, '다시 확인해도 남아야 하는 이야기');
      social.failAlbumSource = false;
      await _tap(
        tester,
        find.byKey(const ValueKey('social-publish-template-retry')),
      );
      expect(find.text('2 / 3 · 작품 소개'), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.first.controller!.text, '내가 고친 작품 제목');
      expect(fields.last.controller!.text, '다시 확인해도 남아야 하는 이야기');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('social-publish-template-consent')),
            )
            .value,
        isFalse,
      );
      expect((container.read(albumRepositoryProvider) as _Albums).reads, 1);
      expect(social.sourceCalls, [42, 42]);
      await _publish(tester);
      expect(social.beginCalls.single.title, '내가 고친 작품 제목');
      expect(social.beginCalls.single.caption, '다시 확인해도 남아야 하는 이야기');
      expect(social.beginCalls.single.includeSourceTemplate, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a late album source after an account change cannot populate publication',
    (tester) async {
      final pending = Completer<SocialTemplateSource?>();
      final social = _Social()..pendingAlbumSource = pending;
      final album = _album();
      final container = _container(social, album: album);
      // Do not settle while the intentional source lookup remains pending.
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: SnapFitTheme.light(),
            home: SocialPublishScreen(album: album),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(social.sourceCalls, [42]);
      container.read(_actor.notifier).change('someone-else');
      await tester.pump();
      pending.complete(_source);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('social-publish-template-consent')),
        findsNothing,
      );
      expect(find.text('계정이 변경됐어요.'), findsOneWidget);
      expect(social.beginCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
