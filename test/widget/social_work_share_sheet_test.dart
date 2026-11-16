import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_work_share_sheet.dart';
import 'package:snap_fit/shared/sharing/feed_share_sheet.dart';

class _Client extends Mock implements SupabaseClient {}

class _Auth extends Mock implements GoTrueClient {}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
const _author = SocialProfile(
  userId: 'owner',
  displayName: '나의 피드',
  handle: 'one',
);

SocialWork _work({String status = 'published'}) => SocialWork(
  id: 'work-one',
  author: _author,
  title: '남겨 둔 하루',
  caption: '함께한 시간을 기억해요.',
  status: status,
  publicationRevision: 3,
  imageUrls: const [
    'https://media.test/storage/v1/object/sign/social/a.png?token=one',
    'https://media.test/storage/v1/object/sign/social/b.png?token=one',
  ],
  createdAt: DateTime.utc(2026, 11, 5),
);

AuthState _event(String id) => AuthState(
  AuthChangeEvent.signedIn,
  Session(
    accessToken: 'fixture',
    tokenType: 'bearer',
    user: User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-11-05T00:00:00Z',
    ),
  ),
);

class _Repository extends SocialRepository {
  _Repository(super.client);
  SocialWork? work = _work();
  Completer<void>? barrier;
  int reads = 0;

  @override
  Future<SocialWork?> fetchWork(String id) async {
    reads++;
    await barrier?.future;
    return work;
  }
}

class _Fixture {
  _Fixture({this.actor = 'owner'}) {
    when(() => client.auth).thenReturn(auth);
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : _event(actor!).session!.user);
    repository = _Repository(client);
  }
  final client = _Client();
  final auth = _Auth();
  final events = StreamController<AuthState>.broadcast(sync: true);
  late final _Repository repository;
  String? actor;
  final loaded = <String>[];
  final sent = <Uint8List>[];
  final links = <Uri>[];
  Completer<Uint8List>? renderBarrier;
  int renders = 0;

  Widget host({bool dark = false, double scale = 1}) => ProviderScope(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((_) => actor),
      socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
      socialRepositoryProvider.overrideWithValue(repository),
      socialWorkShareSnapshotLoaderProvider.overrideWithValue((source) async {
        loaded.add(source);
        return _png;
      }),
      socialWorkShareRasterizerProvider.overrideWithValue((
        page,
        theme,
        loader,
      ) async {
        renders++;
        expect(page.layers, hasLength(1));
        await loader(page.layers.single.originalUrl!);
        return renderBarrier == null ? _png : await renderBarrier!.future;
      }),
      feedImageShareWriterProvider.overrideWithValue((
        bytes,
        filename,
        origin,
      ) async {
        sent.add(bytes);
        expect(filename, endsWith('.png'));
        expect(origin.width, greaterThan(0));
        return const ShareResult('fixture', ShareResultStatus.success);
      }),
      feedLinkShareWriterProvider.overrideWithValue((uri, origin) async {
        links.add(uri);
        return const ShareResult('fixture', ShareResultStatus.success);
      }),
    ],
    child: MaterialApp(
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(child: SocialFeedCard(work: _work())),
      ),
    ),
  );
}

void _viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _paint(WidgetTester tester) async {
  for (var step = 0; step < 8; step++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _paint(tester);
}

void main() {
  testWidgets('card shares the viewed page only after an explicit PNG action', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      _viewport(tester, 390);
      final fixture = _Fixture();
      addTearDown(fixture.events.close);
      await tester.pumpWidget(fixture.host());
      await _paint(tester);
      await tester.drag(
        find.byKey(const ValueKey('social-feed-pages-work-one')),
        const Offset(-320, 0),
      );
      await _paint(tester);
      final readerImage = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey('social-feed-image-work-one-1')),
          matching: find.byType(Image),
        ),
      );
      expect(
        readerImage.image,
        isA<ResizeImage>().having(
          (image) => image.width,
          'reader decode width',
          1440,
        ),
      );
      await _tap(tester, 'social-feed-share-work-one');
      expect(fixture.repository.reads, greaterThanOrEqualTo(2));
      expect(fixture.loaded, [_work().imageUrls[1]]);
      expect(fixture.sent, isEmpty);
      expect(fixture.links, isEmpty);
      final thumbnail = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey('feed-share-photo-work-one-1')),
          matching: find.byType(Image),
        ),
      );
      expect(
        thumbnail.image,
        isA<ResizeImage>().having(
          (image) => image.width,
          'share decode width',
          160,
        ),
      );
      await _tap(tester, 'feed-share-image');
      expect(fixture.sent, [_png]);
      expect(fixture.renders, 1);
      expect(fixture.links, isEmpty);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'feed-share-close');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets(
    'another author shares a public route without downloading an image',
    (tester) async {
      await mockNetworkImagesFor(() async {
        _viewport(tester, 320);
        final fixture = _Fixture(actor: 'other');
        addTearDown(fixture.events.close);
        await tester.pumpWidget(fixture.host(dark: true, scale: 2));
        await _paint(tester);
        await _tap(tester, 'social-feed-share-work-one');
        expect(find.byKey(const ValueKey('feed-share-image')), findsNothing);
        expect(
          find.byKey(const ValueKey('feed-share-copy-caption')),
          findsOneWidget,
        );
        await _tap(tester, 'feed-share-link');
        expect(fixture.links, hasLength(1));
        expect(fixture.links.single.fragment, '/works/work-one');
        expect(fixture.links.single.hasQuery, isFalse);
        expect(fixture.links.single.toString(), isNot(contains('token=')));
        expect(fixture.loaded, isEmpty);
        expect(fixture.sent, isEmpty);
        expect(tester.takeException(), isNull);
        await _tap(tester, 'feed-share-close');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets('raw A to B to A events cancel a pending image share', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      _viewport(tester, 390);
      final fixture = _Fixture()..renderBarrier = Completer<Uint8List>();
      addTearDown(fixture.events.close);
      await tester.pumpWidget(fixture.host());
      await _paint(tester);
      await _tap(tester, 'social-feed-share-work-one');
      expect(fixture.renders, 1);
      // The provider remains owner throughout. Only the raw auth stream sees
      // this same-microtask transition, so provider equality cannot pass it.
      fixture.events.add(_event('other'));
      fixture.events.add(_event('owner'));
      fixture.renderBarrier!.complete(_png);
      await tester.pump(const Duration(milliseconds: 250));
      await _paint(tester);
      expect(find.byKey(const ValueKey('feed-share-image')), findsNothing);
      expect(fixture.sent, isEmpty);
      expect(fixture.links, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('a closed sheet discards a pending raster without reopening', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      _viewport(tester, 390);
      final fixture = _Fixture()..renderBarrier = Completer<Uint8List>();
      addTearDown(fixture.events.close);
      await tester.pumpWidget(fixture.host());
      await _paint(tester);
      await _tap(tester, 'social-feed-share-work-one');
      await _tap(tester, 'feed-share-close');
      fixture.renderBarrier!.complete(_png);
      await _paint(tester);
      expect(find.byKey(const ValueKey('feed-share-image')), findsNothing);
      expect(fixture.sent, isEmpty);
      expect(fixture.events.hasListener, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('a fresh private status prevents the sheet from opening', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      _viewport(tester, 390);
      final fixture = _Fixture();
      fixture.repository.work = _work(status: 'private');
      addTearDown(fixture.events.close);
      await tester.pumpWidget(fixture.host());
      await _paint(tester);
      await _tap(tester, 'social-feed-share-work-one');
      expect(find.byKey(const ValueKey('feed-share-image')), findsNothing);
      expect(fixture.loaded, isEmpty);
      expect(fixture.sent, isEmpty);
      expect(fixture.events.hasListener, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
