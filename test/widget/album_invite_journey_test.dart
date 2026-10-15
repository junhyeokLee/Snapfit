import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/service/album_invite_service.dart';

import '../helpers/fake_album.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _Members extends Mock implements AlbumMemberRepository {}

const _editor = InviteLinkResponse(
  albumId: 7,
  token: 'editor',
  link: 'https://snapfit.example/invite/editor',
);
const _viewer = InviteLinkResponse(
  albumId: 7,
  token: 'viewer',
  link: 'https://snapfit.example/invite/viewer',
);
const _shareButton = ValueKey('inviteShare');
const _copyButton = ValueKey('inviteCopy');

Album _previewAlbum() => fakeAlbum(
  id: 7,
  coverLayersJson: jsonEncode({
    'pages': [
      {
        'index': 0,
        'isCover': true,
        'layers': [
          {
            'id': 'invite-photo',
            'type': 'image',
            'x': 0.0,
            'y': 0.0,
            'width': 1.0,
            'height': 1.0,
            'rotation': 0.0,
            'payload': {
              'originalUrl': 'asset:assets/frame_preview/ocean_shore.jpg',
            },
            'zIndex': 0,
          },
        ],
      },
    ],
  }),
);

Widget _app(
  Widget child,
  _Members members, {
  KakaoInviteShare? share,
  GlobalKey? capture,
  bool dark = false,
  double scale = 1,
}) => ProviderScope(
  overrides: [
    albumMemberRepositoryProvider.overrideWithValue(members),
    kakaoInviteShareProvider.overrideWithValue(
      share ??
          ({required inviteLink, required albumTitle, description}) async =>
              true,
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: capture, child: child!),
      ),
      home: child,
    ),
  ),
);

Future<void> _viewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('INVITE_JOURNEY_QA')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/editor-flow-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'copy and share use exactly the displayed link, not a new invite',
    (tester) async {
      final members = _Members();
      when(
        () => members.invite(7, role: 'EDITOR'),
      ).thenAnswer((_) async => _editor);
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
      String? sharedLink, sharedDescription;
      await tester.pumpWidget(
        _app(
          const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'),
          members,
          share:
              ({required inviteLink, required albumTitle, description}) async {
                sharedLink = inviteLink;
                sharedDescription = description;
                return true;
              },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_copyButton));
      await tester.pumpAndSettle();
      expect(find.text('링크 복사 완료'), findsOneWidget);
      await tester.tap(find.byKey(_shareButton));
      await tester.pumpAndSettle();
      expect(copied, [_editor.link]);
      expect(sharedLink, _editor.link);
      expect(sharedDescription, contains('함께 편집'));
      expect(find.text('카카오톡 공유 화면을 열었어요.'), findsOneWidget);
      expect(find.textContaining('메시지를 보냈'), findsNothing);
      verify(() => members.invite(7, role: 'EDITOR')).called(1);
    },
  );

  testWidgets(
    'viewer share matches new permission and resets copied feedback',
    (tester) async {
      final members = _Members();
      when(
        () => members.invite(7, role: 'EDITOR'),
      ).thenAnswer((_) async => _editor);
      when(
        () => members.invite(7, role: 'VIEWER'),
      ).thenAnswer((_) async => _viewer);
      String? sharedLink, sharedDescription;
      await tester.pumpWidget(
        _app(
          const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'),
          members,
          share:
              ({required inviteLink, required albumTitle, description}) async {
                sharedLink = inviteLink;
                sharedDescription = description;
                return true;
              },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_copyButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('링크 복사 완료'), findsNothing);
      expect(find.text(_editor.link), findsNothing);
      await tester.tap(find.byKey(_shareButton));
      await tester.pumpAndSettle();
      expect(sharedLink, _viewer.link);
      expect(sharedDescription, contains('감상'));
      expect(sharedDescription, isNot(contains('편집')));
      verify(() => members.invite(7, role: 'EDITOR')).called(1);
      verify(() => members.invite(7, role: 'VIEWER')).called(1);
    },
  );

  testWidgets(
    'busy sharing locks actions and falls back to the same copied link',
    (tester) async {
      final members = _Members();
      when(
        () => members.invite(7, role: 'EDITOR'),
      ).thenAnswer((_) async => _editor);
      final completion = Completer<bool>();
      var shares = 0;
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
      await tester.pumpWidget(
        _app(
          const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'),
          members,
          share: ({required inviteLink, required albumTitle, description}) {
            shares++;
            return completion.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_shareButton));
      await tester.pump();
      expect(
        tester.widget<Switch>(find.byType(Switch).first).onChanged,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(_copyButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(_shareButton));
      expect(shares, 1);
      completion.complete(false);
      await tester.pumpAndSettle();
      expect(copied, [_editor.link]);
      expect(find.text('카카오톡 공유를 열지 못해 초대 링크를 복사했어요.'), findsOneWidget);
      expect(find.textContaining('설치되어 있지'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(_shareButton)).onPressed,
        isNotNull,
      );
      verify(() => members.invite(7, role: 'EDITOR')).called(1);
    },
  );

  testWidgets('failed copy retains the link and offers a safe retry', (
    tester,
  ) async {
    final members = _Members();
    when(
      () => members.invite(7, role: 'EDITOR'),
    ).thenAnswer((_) async => _editor);
    var writes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData' && writes++ == 0) {
            throw PlatformException(
              code: 'clipboard_denied',
              message: 'raw secret',
            );
          }
          return null;
        });
    await tester.pumpWidget(
      _app(const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'), members),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_copyButton));
    await tester.pumpAndSettle();
    expect(find.text('링크를 복사하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
    expect(find.textContaining('raw secret'), findsNothing);
    expect(find.text(_editor.link), findsOneWidget);
    await tester.tap(find.byKey(_copyButton));
    await tester.pumpAndSettle();
    expect(writes, 2);
    expect(find.text('링크 복사 완료'), findsOneWidget);
    verify(() => members.invite(7, role: 'EDITOR')).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'copy cannot change permission or duplicate its pending platform call',
    (tester) async {
      final members = _Members();
      when(
        () => members.invite(7, role: 'EDITOR'),
      ).thenAnswer((_) async => _editor);
      final completion = Completer<void>();
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              writes++;
              await completion.future;
            }
            return null;
          });
      await tester.pumpWidget(
        _app(const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'), members),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_copyButton));
      await tester.pump();
      await tester.tap(find.byKey(_copyButton));
      expect(writes, 1);
      expect(
        tester.widget<Switch>(find.byType(Switch).first).onChanged,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byKey(_shareButton)).onPressed,
        isNull,
      );
      completion.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final response in [
    _editor.copyWith(link: 'javascript:bad'),
    _editor.copyWith(albumId: 99),
  ]) {
    testWidgets('invalid invitation cannot be copied or shared: $response', (
      tester,
    ) async {
      final members = _Members();
      when(
        () => members.invite(7, role: 'EDITOR'),
      ).thenAnswer((_) async => response);
      await tester.pumpWidget(
        _app(const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'), members),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('초대 링크 다시 만들기'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(_shareButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(_copyButton)).onPressed,
        isNull,
      );
    });
  }

  testWidgets('existing app-scheme link is still copyable', (tester) async {
    final members = _Members();
    when(() => members.invite(7, role: 'EDITOR')).thenAnswer(
      (_) async => _editor.copyWith(link: 'snapfit://invite?token=editor'),
    );
    await tester.pumpWidget(
      _app(const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'), members),
    );
    await tester.pumpAndSettle();
    expect(find.text('snapfit://invite?token=editor'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(_copyButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'closing during share skips clipboard and snackbar side effects',
    (tester) async {
      final members = _Members();
      when(
        () => members.invite(7, role: 'EDITOR'),
      ).thenAnswer((_) async => _editor);
      final completion = Completer<bool>();
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') writes++;
            return null;
          });
      await tester.pumpWidget(
        _app(
          const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'),
          members,
          share: ({required inviteLink, required albumTitle, description}) =>
              completion.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_shareButton));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Text('다른 화면')));
      completion.complete(false);
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing while fallback clipboard is pending is safe', (
    tester,
  ) async {
    final members = _Members();
    when(
      () => members.invite(7, role: 'EDITOR'),
    ).thenAnswer((_) async => _editor);
    final completion = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') await completion.future;
          return null;
        });
    await tester.pumpWidget(
      _app(
        const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'),
        members,
        share:
            ({required inviteLink, required albumTitle, description}) async =>
                false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_shareButton));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('다른 화면')));
    completion.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late invite issuance cannot start sharing after its screen closes',
    (tester) async {
      final members = _Members();
      final issuance = Completer<InviteLinkResponse>();
      when(
        () => members.invite(7, role: 'EDITOR'),
      ).thenAnswer((_) => issuance.future);
      Future<bool>? result;
      var shares = 0;
      await tester.pumpWidget(
        _app(
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () {
                  result = AlbumInviteService.inviteViaKakaoTalk(
                    ref: ref,
                    albumId: 7,
                    albumTitle: '우리 앨범',
                    allowEditing: true,
                    context: context,
                  );
                  unawaited(result!);
                },
                child: const Text('공유 시작'),
              ),
            ),
          ),
          members,
          share:
              ({required inviteLink, required albumTitle, description}) async {
                shares++;
                return true;
              },
        ),
      );
      await tester.tap(find.text('공유 시작'));
      await tester.pumpWidget(const MaterialApp(home: Text('다른 화면')));
      issuance.complete(_editor);
      await tester.pumpAndSettle();
      expect(await result, false);
      expect(shares, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('share and fallback copy failure never claim a successful copy', (
    tester,
  ) async {
    final members = _Members();
    when(
      () => members.invite(7, role: 'EDITOR'),
    ).thenAnswer((_) async => _editor);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'denied', message: 'private data');
          }
          return null;
        });
    await tester.pumpWidget(
      _app(
        const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범'),
        members,
        share: ({required inviteLink, required albumTitle, description}) async {
          throw StateError('private SDK details');
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_shareButton));
    await tester.pumpAndSettle();
    expect(find.text('공유와 복사를 완료하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    expect(find.text('링크 복사 완료'), findsNothing);
    expect(find.text(_editor.link), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
          'invite fits system insets at $size dark=$dark scale=$scale',
          (tester) async {
            await _viewport(tester, size);
            final members = _Members();
            final first = Completer<InviteLinkResponse>();
            when(
              () => members.invite(7, role: 'EDITOR'),
            ).thenAnswer((_) => first.future);
            when(() => members.invite(7, role: 'VIEWER')).thenThrow(
              Exception(
                'SocketException: host lookup failed, raw private data',
              ),
            );
            final capture = GlobalKey();
            final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
            await tester.pumpWidget(
              _app(
                AlbumInviteScreen(
                  albumId: 7,
                  albumTitle: '우리의 여름, 오래 간직할 장면들',
                  album: _previewAlbum(),
                ),
                members,
                dark: dark,
                scale: scale,
                capture: capture,
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.text('초대 링크를 만드는 중'), findsOneWidget);
            if (scale == 1)
              await _capture(tester, capture, 'invite-loading-$suffix');
            first.complete(_editor);
            await tester.pumpAndSettle();
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('inviteContent')))
                  .height,
              greaterThan(120),
            );
            if (scale == 1)
              await _capture(tester, capture, 'invite-ready-$suffix');
            if (scale == 1) {
              expect(
                tester
                    .getRect(find.byKey(const ValueKey('inviteLinkSurface')))
                    .bottom,
                lessThanOrEqualTo(
                  tester
                      .getRect(find.byKey(const ValueKey('inviteActions')))
                      .top,
                ),
              );
            }
            for (final key in [_copyButton, _shareButton]) {
              final rect = tester.getRect(find.byKey(key));
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(
                rect.bottom,
                lessThanOrEqualTo(
                  size.height - (size.width > size.height ? 24 : 34),
                ),
              );
            }
            if (size.width == 844 && scale == 1) {
              expect(
                tester
                    .getRect(find.byKey(const ValueKey('inviteAlbumIdentity')))
                    .right,
                lessThan(tester.getRect(find.byType(SwitchListTile)).left),
              );
            }
            await tester.ensureVisible(find.byType(Switch).first);
            await tester.pumpAndSettle();
            await tester.tap(find.byType(Switch).first);
            await tester.pumpAndSettle();
            expect(find.text(_editor.link), findsNothing);
            expect(find.textContaining('raw private'), findsNothing);
            await tester.ensureVisible(find.byTooltip('초대 링크 다시 만들기'));
            await tester.pumpAndSettle();
            if (scale == 1)
              await _capture(tester, capture, 'invite-error-$suffix');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
