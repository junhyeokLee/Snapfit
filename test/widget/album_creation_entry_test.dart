import '../support/store_detail_loading.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/presentation/utils/album_creation_entry.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

const _owner = UserInfo(id: 'owner-a', name: '앨범 사용자', provider: 'email');

class _Auth extends AuthViewModel {
  _Auth([this.restoration]);
  final Future<UserInfo?>? restoration;

  @override
  Future<UserInfo?> build() => restoration ?? Future.value(_owner);

  void change(UserInfo? user) => state = AsyncData(user);
}

class _Store implements AlbumCreationDraftStore {
  AlbumCreationDraft? draft;
  Future<AlbumCreationDraft?> Function(String owner)? onLoad;
  final loads = <String>[];
  int writes = 0;
  int removes = 0;

  @override
  Future<AlbumCreationDraft?> load(String owner) {
    loads.add(owner);
    return onLoad?.call(owner) ?? Future.value(draft);
  }

  @override
  Future<void> save(String owner, AlbumCreationDraft value) async {
    writes++;
    draft = value;
  }

  @override
  Future<void> remove(String owner, String draftId) async {
    removes++;
    if (draft?.id == draftId) draft = null;
  }

  @override
  Future<bool> updateLinked(
    String owner,
    String draftId,
    int albumId,
    AlbumCreationDraft Function(AlbumCreationDraft) update,
  ) async => throw StateError('Entry must not update an album');
}

AlbumCreationDraft _draft({
  String id = 'saved-album',
  String title = '사진을 넣어 두었던 여행',
  int revision = 1,
}) => AlbumCreationDraft(
  id: id,
  updatedAt: DateTime.utc(2026, 10, 21, 12, revision),
  title: title,
  cover: defaultCoverSize,
  pageCount: 24,
  step: 0,
  showPhotoFill: false,
  hasSelectedMode: true,
  sourceLabel: '직접 만들기',
  usesPhysicalCanvas: false,
  preserveTypography: false,
);

class _Fixture {
  final store = _Store();
  final navigator = GlobalKey<NavigatorState>();
  late WidgetRef ref;
  late BuildContext entryContext;
  Future<AlbumCreationEntryDecision?>? request;
  bool current = true;

  Widget host({
    String? requestedDraftId,
    String? design = '새로 고른 여행 디자인',
    double textScale = 1,
    Widget? home,
    Future<UserInfo?>? authRestoration,
    bool watchAuth = true,
    List<Override> overrides = const [],
  }) => ProviderScope(
    retry: (_, __) => null,
    overrides: [
      authViewModelProvider.overrideWith(() => _Auth(authRestoration)),
      albumCreationDraftStoreProvider.overrideWithValue(store),
      ...overrides,
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigator,
        theme: SnapFitWebTheme.from(ThemeData(useMaterial3: true)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            entryContext = context;
            if (watchAuth) widgetRef.watch(authViewModelProvider);
            return home ??
                Scaffold(
                  body: Center(
                    child: FilledButton(
                      key: const ValueKey('enter-album'),
                      onPressed: () => request = resolveAlbumCreationEntry(
                        context,
                        widgetRef,
                        selectedDesignTitle: design,
                        requestedDraftId: requestedDraftId,
                        isStillCurrent: () => current,
                      ),
                      child: const Text('앨범 만들기'),
                    ),
                  ),
                );
          },
        ),
      ),
    ),
  );

  void untouched() {
    expect(store.writes, 0);
    expect(store.removes, 0);
  }
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool pending = false,
}) async {
  await tester.ensureVisible(finder);
  if (pending) {
    await tester.pump(const Duration(milliseconds: 350));
  } else {
    await settleStoreDetail(tester);
  }
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  if (pending) {
    await tester.pump(const Duration(milliseconds: 350));
  } else {
    await settleStoreDetail(tester);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  storeDetailTestWidgets(
    'entry awaits initial account restoration before reading drafts',
    (tester) async {
      final account = Completer<UserInfo?>();
      final fixture = _Fixture();
      await tester.pumpWidget(
        fixture.host(authRestoration: account.future, watchAuth: false),
      );
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      expect(fixture.store.loads, isEmpty);
      expect(find.textContaining('로그인 상태를 확인한 뒤'), findsNothing);
      account.complete(_owner);
      await settleStoreDetail(tester);
      expect(await fixture.request, isNotNull);
      expect(fixture.store.loads, ['owner-a']);
      fixture.untouched();
    },
  );

  storeDetailTestWidgets('an empty store explicitly resolves to a new album', (
    tester,
  ) async {
    final fixture = _Fixture();
    await tester.pumpWidget(fixture.host());
    await settleStoreDetail(tester);
    await _tap(tester, _key('enter-album'));
    final result = await fixture.request;
    expect(result, isNotNull);
    expect(result!.draft, isNull);
    expect(_key('album-creation-entry-dialog'), findsNothing);
    fixture.untouched();
  });

  for (final choice in ['cancel', 'resume', 'new']) {
    storeDetailTestWidgets(
      'existing work requires an explicit $choice decision',
      (tester) async {
        final fixture = _Fixture()..store.draft = _draft();
        final original = fixture.store.draft!;
        await tester.pumpWidget(fixture.host());
        await settleStoreDetail(tester);
        await _tap(tester, _key('enter-album'));
        expect(find.text(original.title), findsOneWidget);
        expect(find.textContaining('새로 고른 여행 디자인'), findsOneWidget);
        expect(find.textContaining('기존 임시 저장을 대체'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(_key('album-creation-entry-resume'))
              .onPressed,
          isNotNull,
        );
        await _tap(tester, _key('album-creation-entry-$choice'));
        final result = await fixture.request;
        if (choice == 'cancel') {
          expect(result, isNull);
        } else {
          expect(result, isNotNull);
          expect(result!.draft, choice == 'resume' ? same(original) : isNull);
        }
        expect(fixture.store.draft, same(original));
        fixture.untouched();
      },
    );
  }

  storeDetailTestWidgets(
    'a requested identity resumes the latest stored revision',
    (tester) async {
      final fixture = _Fixture()..store.draft = _draft();
      await tester.pumpWidget(fixture.host(requestedDraftId: 'saved-album'));
      await settleStoreDetail(tester);
      await fixture.ref.read(albumCreationDraftProvider.future);
      final latest = _draft(revision: 2, title: '다른 창에서 이어 쓴 최신 제목');
      fixture.store.draft = latest;
      await _tap(tester, _key('enter-album'));
      expect((await fixture.request)!.draft, same(latest));
      expect(_key('album-creation-entry-dialog'), findsNothing);
      expect(fixture.store.loads, ['owner-a', 'owner-a']);
      fixture.untouched();
    },
  );

  storeDetailTestWidgets(
    'a replaced requested identity shows only the current stored album',
    (tester) async {
      final fixture = _Fixture()..store.draft = _draft(id: 'replacement');
      await tester.pumpWidget(fixture.host(requestedDraftId: 'old-album'));
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      expect(find.text('임시 저장한 앨범이 변경되었어요'), findsOneWidget);
      expect(find.text(fixture.store.draft!.title), findsOneWidget);
      await _tap(tester, _key('album-creation-entry-resume'));
      expect((await fixture.request)!.draft!.id, 'replacement');
      fixture.untouched();
    },
  );

  storeDetailTestWidgets(
    'a deleted requested album never becomes an implicit new album',
    (tester) async {
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host(requestedDraftId: 'deleted-album'));
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      expect(await fixture.request, isNull);
      expect(find.textContaining('변경되었거나 삭제'), findsOneWidget);
      expect(_key('album-creation-entry-dialog'), findsNothing);
      fixture.untouched();
    },
  );

  storeDetailTestWidgets(
    'a change while the decision is open requires a fresh decision',
    (tester) async {
      final fixture = _Fixture()..store.draft = _draft();
      await tester.pumpWidget(fixture.host());
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      final replacement = _draft(revision: 2, title: '결정 중 변경된 원고');
      fixture.store.draft = replacement;
      await _tap(tester, _key('album-creation-entry-new'));
      expect(await fixture.request, isNull);
      expect(fixture.store.draft, same(replacement));
      expect(find.textContaining('변경되었거나 삭제'), findsOneWidget);
      fixture.untouched();
    },
  );

  for (final hadDraft in [false, true]) {
    storeDetailTestWidgets(
      'final validation rejects a newer stored revision (saved=$hadDraft)',
      (tester) async {
        final fixture = _Fixture();
        if (hadDraft) fixture.store.draft = _draft();
        await tester.pumpWidget(fixture.host());
        await settleStoreDetail(tester);
        await _tap(tester, _key('enter-album'));
        if (hadDraft) await _tap(tester, _key('album-creation-entry-new'));
        final decision = (await fixture.request)!;
        expect(
          await validateAlbumCreationEntry(
            fixture.entryContext,
            fixture.ref,
            decision,
          ),
          true,
        );
        final replacement = _draft(revision: 3);
        fixture.store.draft = replacement;
        final validation = validateAlbumCreationEntry(
          fixture.entryContext,
          fixture.ref,
          decision,
        );
        await settleStoreDetail(tester);
        expect(await validation, false);
        expect(fixture.store.draft, same(replacement));
        fixture.untouched();
      },
    );
  }

  storeDetailTestWidgets(
    'load errors stop entry and the retry action invalidates the load',
    (tester) async {
      final fixture = _Fixture();
      var fail = true;
      fixture.store.onLoad = (_) async {
        if (fail) throw StateError('Storage unavailable');
        return null;
      };
      await tester.pumpWidget(fixture.host());
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      expect(await fixture.request, isNull);
      expect(find.textContaining('확인하지 못했어요'), findsOneWidget);
      fail = false;
      await _tap(tester, find.text('다시 확인'));
      await fixture.ref.read(albumCreationDraftProvider.future);
      expect(fixture.store.loads.length, 2);
      await _tap(tester, _key('enter-album'));
      expect(await fixture.request, isNotNull);
      fixture.untouched();
    },
  );

  for (final change in ['account', 'route', 'caller', 'unmount']) {
    storeDetailTestWidgets('$change changes invalidate a pending draft read', (
      tester,
    ) async {
      final pending = Completer<AlbumCreationDraft?>();
      final fixture = _Fixture();
      fixture.store.onLoad = (_) => pending.future;
      await tester.pumpWidget(fixture.host());
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      final request = fixture.request!;
      switch (change) {
        case 'account':
          (fixture.ref.read(authViewModelProvider.notifier) as _Auth).change(
            const UserInfo(id: 'owner-b', name: '다른 사용자', provider: 'email'),
          );
        case 'route':
          unawaited(
            fixture.navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('다른 화면')),
              ),
            ),
          );
        case 'caller':
          fixture.current = false;
        case 'unmount':
          await tester.pumpWidget(const SizedBox.shrink());
      }
      await settleStoreDetail(tester);
      pending.complete(_draft());
      await settleStoreDetail(tester);
      expect(await request, isNull);
      expect(_key('album-creation-entry-dialog'), findsNothing);
      fixture.untouched();
      expect(tester.takeException(), isNull);
    });
  }

  storeDetailTestWidgets(
    'an account change also invalidates an open decision',
    (tester) async {
      final fixture = _Fixture()..store.draft = _draft();
      await tester.pumpWidget(fixture.host());
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      (fixture.ref.read(authViewModelProvider.notifier) as _Auth).change(null);
      await settleStoreDetail(tester);
      await _tap(tester, _key('album-creation-entry-resume'));
      expect(await fixture.request, isNull);
      fixture.untouched();
    },
  );

  storeDetailTestWidgets(
    'an observed SDK account switch blocks a cached profile before reading',
    (tester) async {
      final fixture = _Fixture()..store.draft = _draft();
      await tester.pumpWidget(fixture.host());
      await settleStoreDetail(tester);
      fixture.ref.read(orderSessionOwnerProvider.notifier).observe('owner-b');
      expect(
        fixture.ref.read(authViewModelProvider).asData!.value!.id,
        'owner-a',
      );
      await _tap(tester, _key('enter-album'));
      expect(await fixture.request, isNull);
      expect(fixture.store.loads, isEmpty);
      expect(_key('album-creation-entry-dialog'), findsNothing);
      fixture.untouched();
    },
  );

  storeDetailTestWidgets(
    'an observed SDK logout discards a pending old-account draft read',
    (tester) async {
      final pending = Completer<AlbumCreationDraft?>();
      final fixture = _Fixture();
      fixture.store.onLoad = (_) => pending.future;
      await tester.pumpWidget(fixture.host());
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      fixture.ref.read(orderSessionOwnerProvider.notifier).observe(null);
      expect(
        fixture.ref.read(authViewModelProvider).asData!.value!.id,
        'owner-a',
      );
      pending.complete(_draft());
      await settleStoreDetail(tester);
      expect(await fixture.request, isNull);
      expect(_key('album-creation-entry-dialog'), findsNothing);
      expect(fixture.store.loads, ['owner-a']);
      fixture.untouched();
    },
  );

  storeDetailTestWidgets(
    'SDK owner checks protect open decisions and final validation',
    (tester) async {
      final fixture = _Fixture()..store.draft = _draft();
      await tester.pumpWidget(fixture.host());
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      fixture.ref.read(orderSessionOwnerProvider.notifier).observe('owner-b');
      await _tap(tester, _key('album-creation-entry-resume'));
      expect(await fixture.request, isNull);
      expect(fixture.store.loads.length, 1);

      fixture.ref.read(orderSessionOwnerProvider.notifier).observe('owner-a');
      await _tap(tester, _key('enter-album'));
      await _tap(tester, _key('album-creation-entry-new'));
      final decision = (await fixture.request)!;
      final readsBeforeLogout = fixture.store.loads.length;
      fixture.ref.read(orderSessionOwnerProvider.notifier).observe(null);
      expect(
        fixture.ref.read(authViewModelProvider).asData!.value!.id,
        'owner-a',
      );
      expect(
        await validateAlbumCreationEntry(
          fixture.entryContext,
          fixture.ref,
          decision,
        ),
        false,
      );
      expect(fixture.store.loads.length, readsBeforeLogout);
      fixture.untouched();
    },
  );

  storeDetailTestWidgets(
    'the decision remains usable at 320px and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = _Fixture()
        ..store.draft = _draft(title: '아주 길고 따뜻한 우리 가족의 여름 여행을 기록한 앨범');
      await tester.pumpWidget(fixture.host(textScale: 2));
      await settleStoreDetail(tester);
      await _tap(tester, _key('enter-album'));
      expect(tester.takeException(), isNull);
      await _tap(tester, _key('album-creation-entry-cancel'));
      expect(await fixture.request, isNull);
      fixture.untouched();
    },
  );

  final template = publishedCreationTemplates
      .firstWhere((item) => !item.isPremium)
      .copyWith(
        coverImageUrl: '',
        previewImages: const [],
        pageCount: 24,
        templateJson: jsonEncode({
          'designWidth': 500,
          'designHeight': 500,
          'pages': [
            {'layers': <Object>[]},
          ],
        }),
      );

  storeDetailTestWidgets(
    'detail rejects a draft saved while purchase access is pending',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = _Fixture()..store.draft = _draft();
      final pending = Completer<bool>();
      var accessRequests = 0;
      await tester.pumpWidget(
        fixture.host(
          home: TemplateDetailScreen(template: template),
          overrides: [
            pointShopCatalogProvider.overrideWith(
              (_) async => [
                PointShopProduct(
                  productKey: pointShopTemplateKey(template),
                  kind: 'template',
                  assetId: '${template.id}',
                  title: template.title,
                  pointPrice: 0,
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
            }) {
              accessRequests++;
              return pending.future;
            }),
            pointShopRepositoryProvider.overrideWith(
              (_) => throw StateError('No real purchase calls in entry tests'),
            ),
          ],
        ),
      );
      await settleStoreDetail(tester);
      await _tap(tester, _key('template-detail-use'), pending: true);
      await _tap(tester, _key('album-creation-entry-new'), pending: true);
      expect(accessRequests, 1);
      final replacement = _draft(revision: 4, title: '구매 확인 중 다른 창에서 저장한 원고');
      fixture.store.draft = replacement;
      pending.complete(true);
      await settleStoreDetail(tester);
      expect(find.byType(AlbumCreateFlowScreen), findsNothing);
      expect(find.textContaining('변경되었거나 삭제'), findsOneWidget);
      expect(fixture.store.draft, same(replacement));
      fixture.untouched();
      expect(tester.takeException(), isNull);
    },
  );

  for (final choice in ['cancel', 'resume', 'new', 'selectForCreation']) {
    storeDetailTestWidgets(
      'detail $choice preserves saved work and purchase boundaries',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = _Fixture()..store.draft = _draft();
        final original = fixture.store.draft!;
        var accessRequests = 0;
        await tester.pumpWidget(
          fixture.host(
            home: TemplateDetailScreen(
              template: template,
              selectForCreation: choice == 'selectForCreation',
            ),
            overrides: [
              pointShopCatalogProvider.overrideWith(
                (_) async => [
                  PointShopProduct(
                    productKey: pointShopTemplateKey(template),
                    kind: 'template',
                    assetId: '${template.id}',
                    title: template.title,
                    pointPrice: 0,
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
                accessRequests++;
                return false;
              }),
              pointShopRepositoryProvider.overrideWith(
                (_) =>
                    throw StateError('No real purchase calls in entry tests'),
              ),
            ],
          ),
        );
        await settleStoreDetail(tester);
        await _tap(
          tester,
          choice == 'selectForCreation' && !kIsWeb
              ? find.widgetWithText(FilledButton, '이 디자인 선택')
              : _key('template-detail-use'),
          pending: true,
        );
        if (choice == 'selectForCreation') {
          expect(_key('album-creation-entry-dialog'), findsNothing);
          expect(fixture.store.loads, isEmpty);
          expect(accessRequests, 1);
        } else {
          expect(_key('album-creation-entry-dialog'), findsOneWidget);
          expect(accessRequests, 0);
          await _tap(
            tester,
            _key('album-creation-entry-$choice'),
            pending: true,
          );
          await settleStoreDetail(tester);
          if (choice == 'resume') {
            final flow = tester.widget<AlbumCreateFlowScreen>(
              find.byType(AlbumCreateFlowScreen),
            );
            expect(flow.initialDraft, same(original));
            expect(flow.initialCreationTemplate, isNull);
            expect(accessRequests, 0);
          } else {
            expect(find.byType(AlbumCreateFlowScreen), findsNothing);
            expect(accessRequests, choice == 'new' ? 1 : 0);
          }
        }
        expect(fixture.store.draft, same(original));
        fixture.untouched();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
