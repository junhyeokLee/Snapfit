import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/data/social_profile_photo.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_edit_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_relations_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_works_manage_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/my_moment_archive.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_widgets.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

// These tests provide public social identity only. Do not start the native
// secure-storage account restoration while checking public/private boundaries.
class _NoPrivateAccount extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => null;
}

final _noPrivateAccount = authViewModelProvider.overrideWith(
  _NoPrivateAccount.new,
);

final _emptyMomentPages = socialProfileMomentsPageProvider.overrideWith(
  (_, _) async =>
      const SocialWorkPage(items: [], hasMore: false, nextOffset: 0),
);
final _emptyMomentMonths = socialProfileMomentMonthsPageProvider.overrideWith(
  (_, _) async =>
      const SocialMomentMonthsPage(items: [], hasMore: false, nextOffset: 0),
);

Future<void> _openAlbums(WidgetTester tester) async {
  final tab = find.byKey(const ValueKey('profile-collection-albums'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Override _profileWorksOverride(
  String userId,
  FutureOr<List<SocialWork>> Function(Ref) load,
) => socialProfileWorksPageProvider(SocialProfileWorksQuery(userId))
    .overrideWith((ref) async {
      final works = await load(ref);
      return SocialWorkPage(
        items: works,
        hasMore: false,
        nextOffset: works.length,
      );
    });

Override _relationsOverride(
  SocialRelationsQuery query,
  FutureOr<List<SocialProfile>> Function(Ref) load,
) => socialRelationsPageProvider(query).overrideWith((ref) async {
  final people = await load(ref);
  return SocialProfilePage(
    items: people,
    hasMore: false,
    nextOffset: people.length,
  );
});

class _Repository extends Mock implements SocialRepository {}

class _Picker extends Mock implements ImagePicker {}

class _PickedFile extends Mock implements XFile {}

class _AvatarImageClient extends Mock implements HttpClient {}

class _AvatarImageRequest extends Mock implements HttpClientRequest {}

class _AvatarImageResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _AvatarImageResponse(this.statusCode, this.bytes);

  @override
  final int statusCode;
  final Uint8List bytes;

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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _withAvatarResponses(
  WidgetTester tester,
  Uint8List bytes,
  int Function(Uri) status,
  Future<void> Function(List<String>) body,
) async {
  final previous = painting.debugNetworkImageHttpClientProvider;
  final client = _AvatarImageClient();
  final requests = <String>[];
  when(() => client.getUrl(any())).thenAnswer((invocation) async {
    final uri = invocation.positionalArguments.single as Uri;
    requests.add(uri.toString());
    final request = _AvatarImageRequest();
    when(
      () => request.close(),
    ).thenAnswer((_) async => _AvatarImageResponse(status(uri), bytes));
    return request;
  });
  painting.debugNetworkImageHttpClientProvider = () => client;
  try {
    await body(requests);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    painting.debugNetworkImageHttpClientProvider = previous;
    painting.PaintingBinding.instance.imageCache.clear();
    painting.PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

Future<void> _loadAvatarImage(WidgetTester tester) async {
  final image = find.byType(Image);
  if (image.evaluate().isNotEmpty) {
    await tester.runAsync(
      () => precacheImage(
        tester.widget<Image>(image).image,
        tester.element(find.byType(SocialProfileAvatar)),
        onError: (_, _) {},
      ),
    );
  }
  await tester.pumpAndSettle();
}

Widget _resizingAvatar(
  ValueNotifier<double> size,
  String url,
  Future<String?> Function() refresh, {
  String name = '공개 이름',
}) => ValueListenableBuilder<double>(
  valueListenable: size,
  builder: (_, dimension, _) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 1),
    child: SocialProfileAvatar(
      name: name,
      imageUrl: url,
      size: dimension,
      expandable: true,
      refreshImageUrl: refresh,
    ),
  ),
);

const _me = SocialProfile(
  userId: 'me',
  displayName: '나의 공개 기록',
  handle: 'my.public',
  bio: '공개한 소개만 표시합니다.',
  followersCount: 3,
  followingCount: 2,
  worksCount: 1,
  momentsCount: 5,
);
const _other = SocialProfile(
  userId: 'other',
  displayName: '해린',
  handle: 'haerin.note',
  bio: '여행의 순간을 기록해요.',
  followersCount: 7,
  followingCount: 4,
  momentsCount: 8,
  isFollowing: true,
);
const _third = SocialProfile(
  userId: 'third',
  displayName: '유진',
  handle: 'yujin.log',
);
const _photoMe = SocialProfile(
  userId: 'me',
  displayName: '나의 공개 기록',
  handle: 'my.public',
  bio: '공개한 소개만 표시합니다.',
  avatarPath: 'profiles/me/public.png',
  avatarUrl: 'https://example.test/own-public-photo.png',
);

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  // This suite checks navigation and photos without generating GPU test assets.
  theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
    splashFactory: NoSplash.splashFactory,
  ),
  home: home,
);

Widget _photoEditApp(
  _Repository repository,
  _Picker picker,
  SocialProfile Function() profile, {
  String? Function()? actor,
}) => ProviderScope(
  overrides: [
    _emptyMomentPages,
    _emptyMomentMonths,
    _noPrivateAccount,
    socialCurrentUserIdProvider.overrideWith(
      (_) => actor == null ? 'me' : actor(),
    ),
    socialRepositoryProvider.overrideWithValue(repository),
    ownSocialProfileProvider.overrideWith((_) async => profile()),
  ],
  child: _app(SocialProfileEditScreen(imagePicker: picker)),
);

void _pickResult(_Picker picker, Future<XFile?> Function() result) {
  when(
    () => picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      requestFullMetadata: false,
    ),
  ).thenAnswer((_) => result());
}

Future<void> _openPhotoReview(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('social-profile-change-photo')));
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.text('이 사진을 공개할까요?').evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle();
  expect(find.text('이 사진을 공개할까요?'), findsOneWidget);
}

void main() {
  late Uint8List photoBytes;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xFF668B84), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    photoBytes = bytes!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Uri());
  });
  testWidgets('another public profile never exposes the private shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          _noPrivateAccount,
          socialCurrentUserIdProvider.overrideWith((_) => 'me'),
          socialProfileProvider('other').overrideWith((_) async => _other),
          _profileWorksOverride('other', (_) async => []),
          socialBlockedProfilesProvider.overrideWith((_) async => []),
        ],
        child: _app(const SocialProfileScreen(userId: 'other')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('해린'), findsOneWidget);
    expect(find.text('@haerin.note'), findsOneWidget);
    expect(find.text('공개 기록 8'), findsOneWidget);
    expect(find.text('팔로워 7'), findsOneWidget);
    expect(find.text('팔로잉'), findsOneWidget);
    expect(find.text('프로필 수정'), findsNothing);
    expect(find.byTooltip('공개 앨범 관리'), findsNothing);
    expect(find.text('작품 공개'), findsNothing);
    expect(find.text('기록 남기기'), findsNothing);
    expect(find.text('저장한 작품'), findsNothing);
    expect(find.text('포인트와 결제'), findsNothing);
    expect(find.byTooltip('설정'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('own profile has management while filtering non-public works', (
    tester,
  ) async {
    final published = SocialWork(
      id: 'public-work',
      author: _me,
      title: '공개한 여행 기록',
      createdAt: DateTime(2026, 10, 25),
    );
    final private = SocialWork(
      id: 'private-work',
      author: _me,
      title: '비공개 앨범의 개인 제목',
      status: 'private',
      createdAt: DateTime(2026, 10, 25),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          _noPrivateAccount,
          socialCurrentUserIdProvider.overrideWith((_) => 'me'),
          ownSocialProfileProvider.overrideWith((_) async => _me),
          _profileWorksOverride('me', (_) async => [published, private]),
          socialOwnWorksPageProvider(const SocialOwnWorksQuery()).overrideWith(
            (_) async =>
                const SocialWorkPage(items: [], hasMore: false, nextOffset: 0),
          ),
        ],
        child: _app(const SocialProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await _openAlbums(tester);
    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.text('공개 기록 5'), findsOneWidget);
    expect(find.byTooltip('공개 앨범 관리'), findsOneWidget);
    expect(find.text('기록 남기기'), findsOneWidget);
    expect(find.byTooltip('설정'), findsNothing);
    expect(find.text('공개한 여행 기록'), findsOneWidget);
    expect(find.text('비공개 앨범의 개인 제목'), findsNothing);
    // A public-session fixture alone cannot reveal private account data.
    expect(find.text('저장한 작품'), findsNothing);
    expect(find.byKey(const ValueKey('my-point-balance-card')), findsNothing);
    expect(find.text('이 스타일로 만들기'), findsNothing);
    await tester.ensureVisible(find.byTooltip('공개 앨범 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('공개 앨범 관리'));
    await tester.pumpAndSettle();
    expect(find.byType(SocialWorksManageScreen), findsOneWidget);
    expect(find.text('공개 관리'), findsOneWidget);
    expect(find.text('아직 공개한 기록이나 앨범이 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'own follower removal does not remove the outgoing relationship',
    (tester) async {
      final repository = _Repository();
      var followers = <SocialProfile>[_other];
      when(() => repository.removeFollower('other')).thenAnswer((_) async {
        followers = [];
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _emptyMomentPages,
            _emptyMomentMonths,
            _noPrivateAccount,
            socialCurrentUserIdProvider.overrideWith((_) => 'me'),
            socialRepositoryProvider.overrideWithValue(repository),
            socialBlockedProfilesProvider.overrideWith((_) async => []),
            _relationsOverride(
              const SocialRelationsQuery('me'),
              (_) async => followers,
            ),
          ],
          child: _app(const SocialRelationsScreen(userId: 'me')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('해린 관계 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('팔로워 삭제'));
      await tester.pumpAndSettle();
      expect(find.textContaining('내가 상대를 팔로우하는 관계는 유지'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '팔로워 삭제'));
      await tester.pumpAndSettle();
      verify(() => repository.removeFollower('other')).called(1);
      verifyNever(() => repository.setFollowing(any(), any()));
      expect(find.text('아직 팔로워가 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('relations omit blocked users and never offer self follow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          _noPrivateAccount,
          socialCurrentUserIdProvider.overrideWith((_) => 'me'),
          socialBlockedProfilesProvider.overrideWith((_) async => [_third]),
          _relationsOverride(
            const SocialRelationsQuery('other'),
            (_) async => [_me, _third, _me],
          ),
        ],
        child: _app(const SocialRelationsScreen(userId: 'other')),
      ),
    );
    await tester.pumpAndSettle();
    final myRow = find.byKey(const ValueKey('social-relation-me'));
    expect(myRow, findsOneWidget);
    expect(
      find.descendant(of: myRow, matching: find.byType(OutlinedButton)),
      findsNothing,
    );
    expect(find.text('유진'), findsNothing);
    expect(find.text('팔로워 삭제'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile refetches a committed follow after a lost response', (
    tester,
  ) async {
    final repository = _Repository();
    var profile = _third;
    when(() => repository.setFollowing('third', true)).thenAnswer((_) async {
      profile = const SocialProfile(
        userId: 'third',
        displayName: '유진',
        handle: 'yujin.log',
        isFollowing: true,
        followersCount: 1,
      );
      throw StateError('server committed; response lost');
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          _noPrivateAccount,
          socialCurrentUserIdProvider.overrideWith((_) => 'me'),
          socialRepositoryProvider.overrideWithValue(repository),
          socialProfileProvider('third').overrideWith((_) async => profile),
          _profileWorksOverride('third', (_) async => []),
          socialBlockedProfilesProvider.overrideWith((_) async => []),
        ],
        child: _app(const SocialProfileScreen(userId: 'third')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    expect(find.text('팔로잉'), findsOneWidget);
    expect(find.text('팔로워 1'), findsOneWidget);
    expect(find.textContaining('변경 결과를 확인하지 못했어요.'), findsOneWidget);
    verify(() => repository.setFollowing('third', true)).called(1);
    await tester.tap(find.text('팔로잉'));
    await tester.pumpAndSettle();
    expect(find.text('팔로우를 해제할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.setFollowing('third', false));
    expect(tester.takeException(), isNull);
  });

  testWidgets('relations refresh the final follow state after response loss', (
    tester,
  ) async {
    final repository = _Repository();
    var people = <SocialProfile>[_third];
    when(() => repository.setFollowing('third', true)).thenAnswer((_) async {
      people = const [
        SocialProfile(
          userId: 'third',
          displayName: '유진',
          handle: 'yujin.log',
          isFollowing: true,
        ),
      ];
      throw StateError('server committed; response lost');
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          _noPrivateAccount,
          socialCurrentUserIdProvider.overrideWith((_) => 'me'),
          socialRepositoryProvider.overrideWithValue(repository),
          socialBlockedProfilesProvider.overrideWith((_) async => []),
          _relationsOverride(
            const SocialRelationsQuery('me'),
            (_) async => people,
          ),
        ],
        child: _app(const SocialRelationsScreen(userId: 'me')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('social-relation-third')),
        matching: find.widgetWithText(OutlinedButton, '팔로잉'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('변경 결과를 확인하지 못했어요.'), findsOneWidget);
    verify(() => repository.setFollowing('third', true)).called(1);
    verifyNever(() => repository.setFollowing('third', false));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resizing an expired thumbnail renews and decodes its public URL',
    (tester) async {
      const expired = 'https://example.test/thumbnail-expired.png';
      const fresh = 'https://example.test/thumbnail-renewed.png';
      final size = ValueNotifier(196.0);
      addTearDown(size.dispose);
      final statuses = {expired: HttpStatus.ok, fresh: HttpStatus.ok};
      var refreshes = 0;
      await _withAvatarResponses(
        tester,
        photoBytes,
        (uri) => statuses[uri.toString()] ?? HttpStatus.forbidden,
        (requests) async {
          await tester.pumpWidget(
            _app(
              Scaffold(
                body: _resizingAvatar(size, expired, () async {
                  refreshes++;
                  return fresh;
                }),
              ),
            ),
          );
          await _loadAvatarImage(tester);
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
          expect(refreshes, 0);
          statuses[expired] = HttpStatus.forbidden;
          size.value = 164;
          await tester.pump();
          await _loadAvatarImage(tester);
          await _loadAvatarImage(tester);

          expect(refreshes, 1);
          expect(
            requests.where((url) => url == expired).length,
            greaterThanOrEqualTo(2),
          );
          expect(requests, contains(fresh));
          expect(
            tester.widget<Image>(find.byType(Image)).image,
            ResizeImage(const NetworkImage(fresh), width: 164),
          );
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
          expect(find.text('공'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets('identity changes discard an outstanding thumbnail renewal', (
    tester,
  ) async {
    const expired = 'https://example.test/identity-expired.png';
    const other = 'https://example.test/identity-current.png';
    const stale = 'https://example.test/identity-stale-result.png';
    final size = ValueNotifier(196.0);
    final changed = ValueNotifier(false);
    addTearDown(size.dispose);
    addTearDown(changed.dispose);
    final renewal = Completer<String?>();
    final statuses = {
      expired: HttpStatus.ok,
      other: HttpStatus.ok,
      stale: HttpStatus.ok,
    };
    var refreshes = 0;
    await _withAvatarResponses(
      tester,
      photoBytes,
      (uri) => statuses[uri.toString()] ?? HttpStatus.forbidden,
      (requests) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: changed,
                builder: (_, isOther, _) =>
                    _resizingAvatar(size, isOther ? other : expired, () {
                      refreshes++;
                      return renewal.future;
                    }, name: isOther ? '다른 공개 이름' : '공개 이름'),
              ),
            ),
          ),
        );
        await _loadAvatarImage(tester);
        statuses[expired] = HttpStatus.unauthorized;
        size.value = 164;
        await tester.pump();
        await _loadAvatarImage(tester);
        expect(refreshes, 1);

        changed.value = true;
        await tester.pump();
        await _loadAvatarImage(tester);
        renewal.complete(stale);
        await tester.pumpAndSettle();

        expect(
          tester.widget<Image>(find.byType(Image)).image,
          ResizeImage(const NetworkImage(other), width: 164),
        );
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        expect(requests, isNot(contains(stale)));
        expect(refreshes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('failed thumbnail renewals do not loop after more resizes', (
    tester,
  ) async {
    for (final outcome in ['failed-image', 'null', 'throw']) {
      final expired = 'https://example.test/no-loop-$outcome-expired.png';
      final fresh = 'https://example.test/no-loop-$outcome-renewed.png';
      final size = ValueNotifier(196.0);
      addTearDown(size.dispose);
      final statuses = {expired: HttpStatus.ok, fresh: HttpStatus.forbidden};
      var refreshes = 0;
      await _withAvatarResponses(
        tester,
        photoBytes,
        (uri) => statuses[uri.toString()] ?? HttpStatus.forbidden,
        (_) async {
          await tester.pumpWidget(
            _app(
              Scaffold(
                body: _resizingAvatar(size, expired, () async {
                  refreshes++;
                  if (outcome == 'throw')
                    throw StateError('synthetic renewal failure');
                  return outcome == 'null' ? null : fresh;
                }),
              ),
            ),
          );
          await _loadAvatarImage(tester);
          statuses[expired] = HttpStatus.forbidden;
          size.value = 164;
          await tester.pump();
          await _loadAvatarImage(tester);
          await _loadAvatarImage(tester);
          expect(refreshes, 1, reason: outcome);

          size.value = 148;
          await tester.pump();
          await _loadAvatarImage(tester);
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(refreshes, 1, reason: outcome);
          expect(find.text('공'), findsOneWidget);
          if (outcome == 'null') {
            expect(find.byType(Image), findsNothing);
            expect(find.byTooltip('프로필 사진 크게 보기'), findsNothing);
          }
          expect(tester.takeException(), isNull, reason: outcome);
        },
      );
    }
  });

  testWidgets('a decoded renewal can recover again after its next expiry', (
    tester,
  ) async {
    const expired = 'https://example.test/repeated-original.png';
    const first = 'https://example.test/repeated-first-renewal.png';
    const second = 'https://example.test/repeated-second-renewal.png';
    final size = ValueNotifier(196.0);
    addTearDown(size.dispose);
    final statuses = {
      expired: HttpStatus.ok,
      first: HttpStatus.ok,
      second: HttpStatus.ok,
    };
    var refreshes = 0;
    await _withAvatarResponses(
      tester,
      photoBytes,
      (uri) => statuses[uri.toString()] ?? HttpStatus.forbidden,
      (requests) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: _resizingAvatar(size, expired, () async {
                refreshes++;
                return refreshes == 1 ? first : second;
              }),
            ),
          ),
        );
        await _loadAvatarImage(tester);
        statuses[expired] = HttpStatus.forbidden;
        size.value = 164;
        await tester.pump();
        await _loadAvatarImage(tester);
        await _loadAvatarImage(tester);
        expect(refreshes, 1);
        expect(
          tester.widget<Image>(find.byType(Image)).image,
          ResizeImage(const NetworkImage(first), width: 164),
        );
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);

        statuses[first] = HttpStatus.forbidden;
        size.value = 148;
        await tester.pump();
        await _loadAvatarImage(tester);
        await _loadAvatarImage(tester);

        expect(refreshes, 2);
        expect(requests, contains(second));
        expect(
          tester.widget<Image>(find.byType(Image)).image,
          ResizeImage(const NetworkImage(second), width: 148),
        );
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('a public portrait opens a zoomable photo and can be dismissed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _app(
            const Scaffold(
              body: SocialProfileAvatar(
                name: '공개 이름',
                imageUrl: 'https://example.test/public-avatar.png',
                size: 120,
                expandable: true,
              ),
            ),
          ),
        );
        final provider = tester.widget<Image>(find.byType(Image)).image;
        final context = tester.element(find.byType(SocialProfileAvatar));
        await tester.runAsync(() => precacheImage(provider, context));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SocialProfileAvatar>(find.byType(SocialProfileAvatar))
              .borderRadius,
          isNull,
        );
        expect(find.byIcon(Icons.open_in_full), findsNothing);
        final photoSemantics = tester.getSemantics(
          find.bySemanticsLabel('공개 이름 프로필 사진'),
        );
        expect(photoSemantics.hasFlag(ui.SemanticsFlag.isImage), isTrue);
        expect(photoSemantics.hasFlag(ui.SemanticsFlag.isButton), isTrue);
        expect(
          photoSemantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        await tester.tap(find.byTooltip('프로필 사진 크게 보기'));
        await tester.pumpAndSettle();
        final enlarged = tester
            .widgetList<Image>(find.byType(Image))
            .last
            .image;
        await tester.runAsync(() => precacheImage(enlarged, context));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(find.byTooltip('사진 닫기'), findsOneWidget);
        await tester.tap(find.byTooltip('사진 닫기'));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsNothing);
        expect(tester.takeException(), isNull);
      });
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'zoom resolves a fresh photo URL instead of reusing the cached one',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final fresh = Completer<String?>();
        var requests = 0;
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: SocialProfileAvatar(
                name: '공개 이름',
                imageUrl: 'https://example.test/expired-avatar.png',
                size: 120,
                expandable: true,
                refreshImageUrl: () {
                  requests++;
                  return fresh.future;
                },
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(SocialProfileAvatar));
        final small = tester.widget<Image>(find.byType(Image)).image;
        await tester.runAsync(() => precacheImage(small, context));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('프로필 사진 크게 보기'));
        await tester.pump();
        expect(requests, 1);
        expect(find.byType(InteractiveViewer), findsNothing);
        fresh.complete('https://example.test/refreshed-avatar.png');
        await tester.pumpAndSettle();
        final enlarged = tester
            .widgetList<Image>(find.byType(Image))
            .last
            .image;
        expect(
          enlarged,
          ResizeImage(
            const NetworkImage('https://example.test/refreshed-avatar.png'),
            width: 1600,
          ),
        );
        await tester.runAsync(() => precacheImage(enlarged, context));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        await tester.tap(find.byTooltip('사진 닫기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('unavailable refreshed photo never opens the stale cached URL', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SocialProfileAvatar(
              name: '공개 이름',
              imageUrl: 'https://example.test/old-avatar.png',
              expandable: true,
              refreshImageUrl: () async => null,
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(SocialProfileAvatar));
      final small = tester.widget<Image>(find.byType(Image)).image;
      await tester.runAsync(() => precacheImage(small, context));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('프로필 사진 크게 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.textContaining('현재 볼 수 없는 사진이에요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'session change discards an outstanding public-photo resolution',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final repository = _Repository();
        final fresh = Completer<SocialProfile?>();
        String? actor = 'me';
        const person = SocialProfile(
          userId: 'other',
          displayName: '해린',
          handle: 'haerin.note',
          avatarUrl: 'https://example.test/old-avatar.png',
        );
        when(
          () => repository.fetchProfile('other'),
        ).thenAnswer((_) => fresh.future);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _emptyMomentPages,
              _emptyMomentMonths,
              _noPrivateAccount,
              socialCurrentUserIdProvider.overrideWith((_) => actor),
              socialRepositoryProvider.overrideWithValue(repository),
              socialProfileProvider('other').overrideWith((_) async => person),
              _profileWorksOverride('other', (_) async => []),
              socialBlockedProfilesProvider.overrideWith((_) async => []),
            ],
            child: _app(const SocialProfileScreen(userId: 'other')),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(SocialProfileAvatar));
        final small = tester.widget<Image>(find.byType(Image)).image;
        await tester.runAsync(() => precacheImage(small, context));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('프로필 사진 크게 보기'));
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SocialProfileScreen)),
        );
        actor = null;
        container.invalidate(socialCurrentUserIdProvider);
        await tester.pumpAndSettle();
        fresh.complete(
          const SocialProfile(
            userId: 'other',
            displayName: '해린',
            handle: 'haerin.note',
            avatarUrl: 'https://example.test/new-avatar.png',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsNothing);
        expect(find.textContaining('현재 볼 수 없는 사진이에요.'), findsNothing);
        verify(() => repository.fetchProfile('other')).called(1);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('session change closes an already opened public photo', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      final repository = _Repository();
      String? actor = 'me';
      const person = SocialProfile(
        userId: 'other',
        displayName: '해린',
        handle: 'haerin.note',
        avatarUrl: 'https://example.test/public-avatar.png',
      );
      when(
        () => repository.fetchProfile('other'),
      ).thenAnswer((_) async => person);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _emptyMomentPages,
            _emptyMomentMonths,
            _noPrivateAccount,
            socialCurrentUserIdProvider.overrideWith((_) => actor),
            socialRepositoryProvider.overrideWithValue(repository),
            socialProfileProvider('other').overrideWith((_) async => person),
            _profileWorksOverride('other', (_) async => []),
            socialBlockedProfilesProvider.overrideWith((_) async => []),
          ],
          child: _app(const SocialProfileScreen(userId: 'other')),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialProfileScreen)),
      );
      final context = tester.element(find.byType(SocialProfileAvatar));
      final small = tester.widget<Image>(find.byType(Image)).image;
      await tester.runAsync(() => precacheImage(small, context));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('프로필 사진 크게 보기'));
      await tester.pumpAndSettle();
      final enlarged = tester.widgetList<Image>(find.byType(Image)).last.image;
      await tester.runAsync(() => precacheImage(enlarged, context));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      actor = null;
      container.invalidate(socialCurrentUserIdProvider);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer, skipOffstage: false), findsNothing);
      expect(find.byType(SocialProfileAvatar), findsOneWidget);
      expect(find.textContaining('현재 볼 수 없는 사진이에요.'), findsNothing);
      verify(() => repository.fetchProfile('other')).called(1);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('replaced identity removes only its photo below another dialog', (
    tester,
  ) async {
    final identity = ValueNotifier('공개 이름');
    addTearDown(identity.dispose);
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: identity,
              builder: (_, name, _) => SocialProfileAvatar(
                name: name,
                imageUrl: 'https://example.test/public-avatar.png',
                size: 164,
                borderRadius: BorderRadius.circular(26),
                expandable: true,
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(SocialProfileAvatar));
      final small = tester.widget<Image>(find.byType(Image)).image;
      await tester.runAsync(() => precacheImage(small, context));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      await tester.tap(find.byTooltip('프로필 사진 크게 보기'));
      await tester.pumpAndSettle();
      final enlarged = tester.widgetList<Image>(find.byType(Image)).last.image;
      await tester.runAsync(() => precacheImage(enlarged, context));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      unawaited(
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('사진 위의 다른 대화상자'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('다른 창 닫기'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('사진 위의 다른 대화상자').hitTestable(), findsOneWidget);

      identity.value = '다른 공개 이름';
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer, skipOffstage: false), findsNothing);
      expect(find.text('사진 위의 다른 대화상자').hitTestable(), findsOneWidget);
      await tester.tap(find.text('다른 창 닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(SocialProfileAvatar), findsOneWidget);
      expect(
        tester
            .widget<SocialProfileAvatar>(find.byType(SocialProfileAvatar))
            .name,
        '다른 공개 이름',
      );
      expect(find.byTooltip('프로필 사진 크게 보기').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('canceling the gallery never requests a photo update', (
    tester,
  ) async {
    final repository = _Repository();
    final picker = _Picker();
    _pickResult(picker, () async => null);
    await tester.pumpWidget(_photoEditApp(repository, picker, () => _me));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-profile-change-photo')));
    await tester.pumpAndSettle();
    expect(find.text('이 사진을 공개할까요?'), findsNothing);
    verifyNever(() => repository.updateOwnPhoto(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'photo review requires explicit consent and cancellation keeps drafts',
    (tester) async {
      final repository = _Repository();
      final picker = _Picker();
      _pickResult(
        picker,
        () async => XFile.fromData(
          photoBytes,
          name: 'selected.png',
          mimeType: 'image/png',
        ),
      );
      await tester.pumpWidget(_photoEditApp(repository, picker, () => _me));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('social-profile-bio')),
        '아직 저장하지 않은 소개',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('social-profile-change-photo')),
      );
      await _openPhotoReview(tester);
      expect(find.textContaining('선택한 사진 전체가 공개 프로필에 표시돼요.'), findsOneWidget);
      verifyNever(() => repository.updateOwnPhoto(any()));
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.updateOwnPhoto(any()));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('social-profile-bio')),
            )
            .controller!
            .text,
        '아직 저장하지 않은 소개',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed photo updates independently without saving typed bio',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final repository = _Repository();
        final picker = _Picker();
        var profile = _me;
        _pickResult(
          picker,
          () async => XFile.fromData(
            photoBytes,
            name: 'selected.png',
            mimeType: 'image/png',
          ),
        );
        when(
          () => repository.updateOwnPhoto(any()),
        ).thenAnswer((_) async => profile = _photoMe);
        await tester.pumpWidget(
          _photoEditApp(repository, picker, () => profile),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('social-profile-bio')),
          '사진과 별개로 쓰던 소개',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('social-profile-change-photo')),
        );
        await _openPhotoReview(tester);
        verifyNever(() => repository.updateOwnPhoto(any()));
        await tester.tap(find.widgetWithText(FilledButton, '공개 사진으로 등록'));
        await tester.pumpAndSettle();
        verify(() => repository.updateOwnPhoto(any())).called(1);
        verifyNever(
          () => repository.upsertOwnProfile(
            displayName: any(named: 'displayName'),
            handle: any(named: 'handle'),
            bio: any(named: 'bio'),
          ),
        );
        expect(
          find.byKey(const ValueKey('social-profile-remove-photo')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('social-profile-bio')),
              )
              .controller!
              .text,
          '사진과 별개로 쓰던 소개',
        );
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'lost photo reply refetches committed portrait while retaining text',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final repository = _Repository();
        final picker = _Picker();
        var profile = _me;
        _pickResult(
          picker,
          () async => XFile.fromData(
            photoBytes,
            name: 'selected.png',
            mimeType: 'image/png',
          ),
        );
        when(() => repository.updateOwnPhoto(any())).thenAnswer((_) async {
          profile = _photoMe;
          throw StateError('photo committed; response lost');
        });
        await tester.pumpWidget(
          _photoEditApp(repository, picker, () => profile),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('social-profile-bio')),
          '유지할 소개',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('social-profile-change-photo')),
        );
        await _openPhotoReview(tester);
        await tester.tap(find.widgetWithText(FilledButton, '공개 사진으로 등록'));
        await tester.pumpAndSettle();
        expect(find.textContaining('사진 변경 결과를 확인하지 못했어요.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('social-profile-remove-photo')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('social-profile-bio')),
              )
              .controller!
              .text,
          '유지할 소개',
        );
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('oversized picked file is rejected before decode or upload', (
    tester,
  ) async {
    final repository = _Repository();
    final picker = _Picker();
    final file = _PickedFile();
    when(
      () => file.length(),
    ).thenAnswer((_) async => socialProfilePhotoInputMaxBytes + 1);
    _pickResult(picker, () async => file);
    await tester.pumpWidget(_photoEditApp(repository, picker, () => _me));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-profile-change-photo')));
    await tester.pumpAndSettle();
    expect(find.text('20MB 이하의 사진을 선택해 주세요.'), findsOneWidget);
    verifyNever(() => file.readAsBytes());
    verifyNever(() => repository.updateOwnPhoto(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo removal needs confirmation and keeps unsaved fields', (
    tester,
  ) async {
    final repository = _Repository();
    final picker = _Picker();
    var profile = const SocialProfile(
      userId: 'me',
      displayName: '나의 공개 기록',
      handle: 'my.public',
      avatarPath: 'profiles/me/public.png',
    );
    when(
      () => repository.removeOwnPhoto(),
    ).thenAnswer((_) async => profile = _me);
    await tester.pumpWidget(_photoEditApp(repository, picker, () => profile));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('social-profile-bio')),
      '지우지 않을 소개',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('social-profile-remove-photo')),
    );
    await tester.tap(find.byKey(const ValueKey('social-profile-remove-photo')));
    await tester.pumpAndSettle();
    verifyNever(() => repository.removeOwnPhoto());
    await tester.tap(find.widgetWithText(FilledButton, '사진 삭제'));
    await tester.pumpAndSettle();
    verify(() => repository.removeOwnPhoto()).called(1);
    expect(
      find.byKey(const ValueKey('social-profile-remove-photo')),
      findsNothing,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('social-profile-bio')),
          )
          .controller!
          .text,
      '지우지 않을 소개',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late gallery result after logout never opens review or uploads',
    (tester) async {
      final repository = _Repository();
      final picker = _Picker();
      final chosen = Completer<XFile?>();
      String? actor = 'me';
      _pickResult(picker, () => chosen.future);
      await tester.pumpWidget(
        _photoEditApp(repository, picker, () => _me, actor: () => actor),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('social-profile-change-photo')),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialProfileEditScreen)),
      );
      actor = null;
      container.invalidate(socialCurrentUserIdProvider);
      await tester.pumpAndSettle();
      chosen.complete(
        XFile.fromData(photoBytes, name: 'selected.png', mimeType: 'image/png'),
      );
      await tester.pumpAndSettle();
      expect(find.text('로그인이 필요해요.'), findsOneWidget);
      expect(find.text('이 사진을 공개할까요?'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      verifyNever(() => repository.updateOwnPhoto(any()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late photo RPC reply cannot restore a logged-out profile', (
    tester,
  ) async {
    final repository = _Repository();
    final picker = _Picker();
    final reply = Completer<SocialProfile>();
    String? actor = 'me';
    _pickResult(
      picker,
      () async => XFile.fromData(
        photoBytes,
        name: 'selected.png',
        mimeType: 'image/png',
      ),
    );
    when(
      () => repository.updateOwnPhoto(any()),
    ).thenAnswer((_) => reply.future);
    await tester.pumpWidget(
      _photoEditApp(repository, picker, () => _me, actor: () => actor),
    );
    await tester.pumpAndSettle();
    await _openPhotoReview(tester);
    await tester.tap(find.widgetWithText(FilledButton, '공개 사진으로 등록'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialProfileEditScreen)),
    );
    actor = null;
    container.invalidate(socialCurrentUserIdProvider);
    await tester.pumpAndSettle();
    reply.complete(_photoMe);
    await tester.pumpAndSettle();
    expect(find.text('로그인이 필요해요.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('공개 프로필 사진을 변경했어요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session change dismisses a private selected-photo review', (
    tester,
  ) async {
    final repository = _Repository();
    final picker = _Picker();
    String? actor = 'me';
    _pickResult(
      picker,
      () async => XFile.fromData(
        photoBytes,
        name: 'selected.png',
        mimeType: 'image/png',
      ),
    );
    await tester.pumpWidget(
      _photoEditApp(repository, picker, () => _me, actor: () => actor),
    );
    await tester.pumpAndSettle();
    await _openPhotoReview(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialProfileEditScreen)),
    );
    actor = null;
    container.invalidate(socialCurrentUserIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('이 사진을 공개할까요?'), findsNothing);
    expect(find.text('로그인이 필요해요.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    verifyNever(() => repository.updateOwnPhoto(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing or private-file avatar has initials and no photo action',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: SocialProfileAvatar(
              name: '공개 이름',
              imageUrl: 'file:///private-account-photo.jpg',
              size: 120,
              expandable: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('공'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byTooltip('프로필 사진 크게 보기'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewportWidth in [320.0, 390.0, 820.0, 1440.0]) {
    testWidgets('profile opens with large photos at $viewportWidth pixels', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(viewportWidth, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ratios = [.75, 1.5, 3.0];
      final works = List.generate(
        ratios.length,
        (index) => SocialWork(
          id: 'responsive-$index',
          author: _me,
          title: '함께 남긴 순간 $index',
          aspectRatio: ratios[index],
          createdAt: DateTime(2026, 10, 25),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _emptyMomentPages,
            _emptyMomentMonths,
            _noPrivateAccount,
            socialCurrentUserIdProvider.overrideWith((_) => 'me'),
            ownSocialProfileProvider.overrideWith((_) async => _me),
            _profileWorksOverride('me', (_) async => works),
          ],
          child: _app(const SocialProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await _openAlbums(tester);
      final portrait = tester.getRect(find.byType(SocialProfileAvatar));
      final expectedPortrait = viewportWidth == 320
          ? 80.0
          : viewportWidth == 390
          ? 88.0
          : 112.0;
      expect(portrait.width, expectedPortrait);
      expect(portrait.height, expectedPortrait);
      expect(
        tester
            .widget<SocialProfileAvatar>(find.byType(SocialProfileAvatar))
            .borderRadius,
        isNotNull,
      );
      final edit = tester.getRect(
        find
            .ancestor(
              of: find.text('프로필 수정'),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            )
            .first,
      );
      final publish = tester.getRect(
        find
            .ancestor(
              of: find.text('기록 남기기'),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            )
            .first,
      );
      expect(edit.top, publish.top);
      expect(edit.width, closeTo(publish.width, .01));
      expect(find.byTooltip('공개 앨범 관리'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SocialProfileGallery),
          matching: find.text('공개 앨범'),
        ),
        findsOneWidget,
      );
      expect(find.text('공개한 작품'), findsNothing);
      expect(find.byTooltip('설정'), findsNothing);
      expect(find.text('모아 보기'), findsOneWidget);
      expect(find.text('크게 보기'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .selected,
        {true},
      );
      final first = find.byKey(
        const ValueKey('social-profile-work-responsive-0'),
      );
      final second = find.byKey(
        const ValueKey('social-profile-work-responsive-1'),
      );
      final third = find.byKey(
        const ValueKey('social-profile-work-responsive-2'),
      );
      if (viewportWidth < 700) {
        expect(
          tester.getSize(first).width,
          greaterThanOrEqualTo(viewportWidth - 40),
        );
        expect(
          tester.getTopLeft(second).dy,
          greaterThan(tester.getTopLeft(first).dy),
        );
      } else {
        expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        expect(
          tester.getTopLeft(second).dx,
          greaterThan(tester.getTopLeft(first).dx),
        );
        expect(
          tester.getTopLeft(third).dy,
          greaterThan(tester.getTopLeft(first).dy),
        );
      }
      for (var index = 0; index < ratios.length; index++) {
        final photo = find.descendant(
          of: find.byKey(ValueKey('social-profile-work-responsive-$index')),
          matching: find.byType(AspectRatio),
        );
        final size = tester.getSize(photo);
        expect(size.width / size.height, closeTo(ratios[index], .001));
      }
      if (viewportWidth == 390) {
        final firstPhoto = find.descendant(
          of: first,
          matching: find.byType(AspectRatio),
        );
        expect(tester.getTopLeft(firstPhoto).dy, lessThan(760));
      }
      expect(find.text('원본 앨범은 비공개로 유지돼요.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile profile opens large and can collect or open its works', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final works = List.generate(
      3,
      (index) => SocialWork(
        id: 'gallery-$index',
        author: _me,
        title: '작품 $index',
        aspectRatio: .75,
        createdAt: DateTime(2026, 10, 25),
      ),
    );
    String? opened;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: SocialProfileContent(
                child: SocialProfileGallery(
                  works: works,
                  onOpenWork: (work) => opened = work.id,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('모아 보기'), findsOneWidget);
      expect(find.text('크게 보기'), findsOneWidget);
      final first = find.byKey(const ValueKey('social-profile-work-gallery-0'));
      final second = find.byKey(
        const ValueKey('social-profile-work-gallery-1'),
      );
      final initialWidth = tester.getSize(first).width;
      expect(initialWidth, greaterThanOrEqualTo(350));
      expect(
        tester.getTopLeft(second).dy,
        greaterThan(tester.getTopLeft(first).dy),
      );
      final workSemantics = tester.getSemantics(
        find.bySemanticsLabel('작품 0, 0쪽 앨범 보기'),
      );
      expect(workSemantics.hasFlag(ui.SemanticsFlag.isButton), isTrue);
      expect(
        workSemantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(first);
      expect(opened, 'gallery-0');
      await tester.tap(find.byTooltip('모아 보기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .selected,
        {false},
      );
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(second).dx,
        greaterThan(tester.getTopLeft(first).dx),
      );
      expect(tester.getSize(first).width, lessThan(initialWidth * .6));
      await tester.tap(find.byTooltip('크게 보기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .selected,
        {true},
      );
      expect(tester.getSize(first).width, closeTo(initialWidth, .01));
      expect(
        tester.getTopLeft(second).dy,
        greaterThan(tester.getTopLeft(first).dy),
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('gallery view labels stay usable with narrow dark large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SocialProfileContent(
                child: SocialProfileGallery(
                  works: [
                    SocialWork(
                      id: 'accessible-gallery',
                      author: _me,
                      title: '크게 보아도 읽기 편한 작품',
                      createdAt: DateTime(2026, 10, 25),
                    ),
                  ],
                  onOpenWork: (_) {},
                ),
              ),
            ),
          ),
        ),
        dark: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('모아 보기'), findsOneWidget);
    expect(find.text('크게 보기'), findsOneWidget);
    await tester.tap(find.text('크게 보기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {true},
    );
    await tester.tap(find.text('모아 보기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {false},
    );
    expect(tester.takeException(), isNull);
  });

  for (final viewportWidth in [820.0, 1440.0]) {
    testWidgets('wide gallery keeps large pairs at $viewportWidth pixels', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(viewportWidth, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final works = List.generate(
        3,
        (index) => SocialWork(
          id: 'wide-$index',
          author: _me,
          title: '작품 $index',
          aspectRatio: [3.0, .75, 1.5][index],
          createdAt: DateTime(2026, 10, 25),
        ),
      );
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: SingleChildScrollView(
                child: SocialProfileContent(
                  child: SocialProfileGallery(works: works, onOpenWork: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('social-profile-work-wide-0'));
        final second = find.byKey(const ValueKey('social-profile-work-wide-1'));
        final third = find.byKey(const ValueKey('social-profile-work-wide-2'));
        final initialWidth = tester.getSize(first).width;
        expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        expect(
          tester.getTopLeft(third).dy,
          greaterThan(tester.getTopLeft(first).dy),
        );
        expect(
          tester.getTopLeft(third).dy,
          closeTo(tester.getBottomLeft(first).dy + 32, .01),
        );
        expect(
          tester.getTopLeft(third).dy,
          lessThan(tester.getBottomLeft(second).dy),
        );
        final firstSemantics = tester.getSemantics(
          find.bySemanticsLabel('작품 0, 0쪽 앨범 보기'),
        );
        final orderedWorks = firstSemantics.parent!
            .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
            .where((node) => node.label.endsWith('쪽 앨범 보기'))
            .toList();
        expect(orderedWorks.map((node) => node.label), [
          '작품 0, 0쪽 앨범 보기',
          '작품 1, 0쪽 앨범 보기',
          '작품 2, 0쪽 앨범 보기',
        ]);
        expect(
          orderedWorks.map((node) => (node.sortKey! as OrdinalSortKey).order),
          [0.0, 1.0, 2.0],
        );
        expect(initialWidth, greaterThan(350));
        await tester.tap(find.byTooltip('모아 보기'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
              .selected,
          {false},
        );
        if (viewportWidth == 1440) {
          expect(tester.getTopLeft(first).dy, tester.getTopLeft(third).dy);
          expect(tester.getSize(first).width, lessThan(initialWidth * .7));
        } else {
          expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
          expect(
            tester.getTopLeft(third).dy,
            greaterThan(tester.getTopLeft(first).dy),
          );
        }
        await tester.tap(find.byTooltip('크게 보기'));
        await tester.pumpAndSettle();
        expect(tester.getSize(first).width, closeTo(initialWidth, .01));
        expect(
          tester.getTopLeft(third).dy,
          greaterThan(tester.getTopLeft(first).dy),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('a single desktop work keeps a full width page in large mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(820, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final work = SocialWork(
      id: 'single-hero',
      author: _me,
      title: '한 장으로 남긴 풍경',
      aspectRatio: 2.4,
      createdAt: DateTime(2026, 10, 25),
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SingleChildScrollView(
            child: SocialProfileContent(
              child: SocialProfileGallery(works: [work], onOpenWork: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('social-profile-work-single-hero'));
    final photo = find.descendant(of: tile, matching: find.byType(AspectRatio));
    final largeWidth = tester.getSize(photo).width;
    expect(largeWidth, greaterThanOrEqualTo(760));
    expect(largeWidth / tester.getSize(photo).height, closeTo(2.4, .001));
    await tester.tap(find.byTooltip('모아 보기'));
    await tester.pumpAndSettle();
    expect(tester.getSize(photo).width, lessThan(largeWidth * .6));
    await tester.tap(find.byTooltip('크게 보기'));
    await tester.pumpAndSettle();
    expect(tester.getSize(photo).width, closeTo(largeWidth, .01));
    expect(
      tester.getSize(photo).width / tester.getSize(photo).height,
      closeTo(2.4, .001),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('own profile stays usable at 320 pixels with dark large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final work = SocialWork(
      id: 'large-text-profile',
      author: _me,
      title: '크게 보아도 읽기 편한 공개 작품',
      aspectRatio: .75,
      createdAt: DateTime(2026, 10, 25),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          _noPrivateAccount,
          socialCurrentUserIdProvider.overrideWith((_) => 'me'),
          ownSocialProfileProvider.overrideWith((_) async => _me),
          _profileWorksOverride('me', (_) async => [work]),
        ],
        child: _app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: const SocialProfileScreen(),
            ),
          ),
          dark: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openAlbums(tester);
    final portrait = tester.getRect(find.byType(SocialProfileAvatar));
    expect(portrait.width, 80);
    expect(
      tester.getTopLeft(find.text(_me.displayName)).dy,
      greaterThan(portrait.bottom),
    );
    expect(find.byTooltip('공개 앨범 관리'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SocialProfileGallery),
        matching: find.text('공개 앨범'),
      ),
      findsOneWidget,
    );
    expect(find.text('공개한 작품'), findsNothing);
    expect(find.byTooltip('설정'), findsNothing);
    final editButton = find
        .ancestor(
          of: find.text('프로필 수정'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        )
        .first;
    final publishButton = find
        .ancestor(
          of: find.text('기록 남기기'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        )
        .first;
    final edit = tester.getRect(editButton);
    final publish = tester.getRect(publishButton);
    expect(edit.width, greaterThanOrEqualTo(280));
    expect(publish.width, closeTo(edit.width, .01));
    expect(publish.top, greaterThanOrEqualTo(edit.bottom));
    await tester.ensureVisible(editButton);
    await tester.pumpAndSettle();
    expect(editButton.hitTestable(), findsOneWidget);
    await tester.ensureVisible(publishButton);
    await tester.pumpAndSettle();
    expect(publishButton.hitTestable(), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('모아 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('모아 보기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {false},
    );
    final tile = find.byKey(
      const ValueKey('social-profile-work-large-text-profile'),
    );
    expect(tester.getSize(tile).width, greaterThanOrEqualTo(280));
    await tester.tap(find.byTooltip('크게 보기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {true},
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tile.hitTestable(), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('social-profile-private-me'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(find.byType(MyMomentArchive, skipOffstage: false), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SnapfitImage &&
            [widget.urlOrGs, ...widget.fallbackSources].any(
              (source) =>
                  source.startsWith('supabase://album-assets/me/moments/'),
            ),
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile save validates the handle and ignores a lost session', (
    tester,
  ) async {
    String? actor = 'me';
    final repository = _Repository();
    final save = Completer<SocialProfile>();
    when(
      () => repository.upsertOwnProfile(
        displayName: any(named: 'displayName'),
        handle: any(named: 'handle'),
        bio: any(named: 'bio'),
      ),
    ).thenAnswer((_) => save.future);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          _noPrivateAccount,
          socialCurrentUserIdProvider.overrideWith((_) => actor),
          socialRepositoryProvider.overrideWithValue(repository),
          ownSocialProfileProvider.overrideWith((_) async => _me),
        ],
        child: _app(const SocialProfileEditScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('social-profile-handle')),
      'bad handle!',
    );
    await tester.ensureVisible(find.text('프로필 저장'));
    await tester.tap(find.text('프로필 저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아이디는 영문·숫자·점·밑줄로'), findsOneWidget);
    verifyNever(
      () => repository.upsertOwnProfile(
        displayName: any(named: 'displayName'),
        handle: any(named: 'handle'),
        bio: any(named: 'bio'),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('social-profile-handle')),
      'my.updated',
    );
    await tester.ensureVisible(find.text('프로필 저장'));
    await tester.tap(find.text('프로필 저장'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialProfileEditScreen)),
    );
    actor = null;
    container.invalidate(socialCurrentUserIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('로그인이 필요해요.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    save.complete(_me);
    await tester.pumpAndSettle();
    expect(find.text('공개 프로필을 저장했어요.'), findsNothing);
    expect(find.byType(SocialProfileEditScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('identity and relationship controls fit narrow dark large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SocialProfileContent(
                child: Column(
                  children: [
                    SocialProfileIdentity(
                      name: '긴 이름으로 남기는 여행의 기록',
                      handle: 'my.long.public.archive',
                      bio: '함께 오래 간직하고 싶은 순간들을 모읍니다.',
                      worksCount: 28,
                      followersCount: 1234,
                      followingCount: 567,
                      onFollowers: () {},
                      onFollowing: () {},
                    ),
                    SocialRelationTile(
                      name: '아주 긴 공개 닉네임의 창작자',
                      handle: 'a.very.long.public.handle',
                      onOpenProfile: () {},
                      actions: [
                        OutlinedButton(
                          onPressed: () {},
                          child: const Text('팔로잉'),
                        ),
                        IconButton(
                          onPressed: () {},
                          tooltip: '관계 관리',
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        dark: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('팔로워 1234'), findsOneWidget);
    expect(find.text('팔로잉'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
