import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:snap_fit/shared/sharing/feed_share_sheet.dart';

Uint8List _png(int color) {
  final image = img.Image(width: 32, height: 24);
  img.fill(image, color: img.ColorRgb8(color, 80, 100));
  return Uint8List.fromList(img.encodePng(image));
}

class _Fixture {
  bool active = true;
  int validations = 0, shares = 0, links = 0;
  final rendered = <String>[];
  final first = _png(20), second = _png(160);
  Uint8List? shared;
  Rect? origin;
  Uri? sharedUri;
  Future<void> Function()? validator;
  Future<Uint8List> Function(String id)? renderer;
  Future<ShareResult> Function()? writer;
  late BuildContext host;

  Future<void> mount(
    WidgetTester tester, {
    String? initialPhotoId,
    bool linkOnly = false,
    bool darkLarge = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedImageShareWriterProvider.overrideWithValue((
            bytes,
            name,
            rect,
          ) async {
            shares++;
            shared = bytes;
            origin = rect;
            expect(name, endsWith('.png'));
            return writer == null
                ? const ShareResult('', ShareResultStatus.unavailable)
                : writer!();
          }),
          feedLinkShareWriterProvider.overrideWithValue((uri, rect) async {
            links++;
            sharedUri = uri;
            origin = rect;
            return const ShareResult('', ShareResultStatus.success);
          }),
        ],
        child: MaterialApp(
          theme: darkLarge ? ThemeData.dark() : ThemeData.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(darkLarge ? 2 : 1)),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              host = context;
              return Scaffold(
                body: Center(
                  child: TextButton(
                    key: const ValueKey('open-share'),
                    onPressed: () => unawaited(
                      showFeedShareSheet(
                        context,
                        title: '오늘의 기록 공유',
                        caption: '오늘 함께 걸었던 바다.',
                        photos: linkOnly
                            ? []
                            : [
                                for (final id in ['first', 'second'])
                                  FeedSharePhoto(
                                    id: id,
                                    preview: (_) =>
                                        const ColoredBox(color: Colors.teal),
                                    render: (_, active) async {
                                      rendered.add(id);
                                      return renderer == null
                                          ? (id == 'first' ? first : second)
                                          : renderer!(id);
                                    },
                                  ),
                              ],
                        initialPhotoId: initialPhotoId,
                        note: '사진만 공유해요. 기록의 공개 범위는 바뀌지 않아요.',
                        publicUri: linkOnly
                            ? Uri.parse(
                                'https://snapfit.example/#/works/public-1',
                              )
                            : null,
                        isActive: () => active,
                        validate: () async {
                          validations++;
                          await validator?.call();
                        },
                      ),
                    ),
                    child: const Text('공유 열기'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-share')));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
    });
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'only the explicitly chosen PNG reaches the system writer with an iPad anchor',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester, initialPhotoId: 'second');
      expect(f.rendered, ['second']);
      expect(f.shares, 0);
      await f.tap(tester, 'feed-share-image');
      expect(f.shares, 1);
      expect(f.shared, orderedEquals(f.second));
      expect(f.validations, 2);
      expect(f.links, 0);
      expect(f.origin!.width, greaterThan(0));
      expect(f.origin!.height, greaterThan(0));
      expect(find.text('공유창이나 저장된 이미지를 확인해 주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching photos discards the first payload and revalidates the next selection',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      await f.tap(tester, 'feed-share-photo-second');
      expect(f.rendered, ['first', 'second']);
      await f.tap(tester, 'feed-share-image');
      expect(f.shared, orderedEquals(f.second));
      expect(f.shares, 1);
      expect(f.validations, 3);
    },
  );

  testWidgets('closing an in-flight export never opens a system share sheet', (
    tester,
  ) async {
    final f = _Fixture();
    await f.mount(tester);
    final second = Completer<Uint8List>();
    f.renderer = (_) => second.future;
    await tester.tap(find.byKey(const ValueKey('feed-share-photo-second')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('feed-share-image')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('feed-share-close')));
    await tester.pump();
    second.complete(f.second);
    await tester.pumpAndSettle();
    expect(f.shares, 0);
    expect(find.byKey(const ValueKey('feed-share-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closing during final validation cancels handoff before the exit animation ends',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      final pending = Completer<void>();
      f.validator = () => pending.future;
      await tester.tap(find.byKey(const ValueKey('feed-share-image')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('feed-share-close')));
      await tester.pump();
      pending.complete();
      await tester.pumpAndSettle();
      expect(f.shares, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account invalidation removes private pixels and closes only the share route',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      f.active = false;
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feed-share-preview')), findsNothing);
      expect(find.byKey(const ValueKey('open-share')), findsOneWidget);
      expect(f.shares, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a changed source before handoff clears the prepared PNG without sending it',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      f.validator = () async => throw StateError('record revision changed');
      await f.tap(tester, 'feed-share-image');
      expect(f.shares, 0);
      expect(find.byKey(const ValueKey('feed-share-error')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('feed-share-image')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'a pending handoff cannot be submitted twice and cancellation is not reported as posting',
    (tester) async {
      final f = _Fixture();
      final pending = Completer<ShareResult>();
      f.writer = () => pending.future;
      await f.mount(tester);
      await tester.tap(find.byKey(const ValueKey('feed-share-image')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('feed-share-image')));
      await tester.pump();
      expect(f.shares, 1);
      pending.complete(const ShareResult('', ShareResultStatus.dismissed));
      await tester.pumpAndSettle();
      expect(find.text('공유를 취소했어요.'), findsOneWidget);
      expect(find.text('선택한 앱에서 게시하거나 전송을 마쳐 주세요.'), findsNothing);
    },
  );

  testWidgets('public link-only sharing exports no photo or capability URL', (
    tester,
  ) async {
    final f = _Fixture();
    await f.mount(tester, linkOnly: true);
    expect(find.byKey(const ValueKey('feed-share-image')), findsNothing);
    await f.tap(tester, 'feed-share-link');
    expect(f.sharedUri.toString(), 'https://snapfit.example/#/works/public-1');
    expect(f.rendered, isEmpty);
    expect(f.shares, 0);
    expect(f.links, 1);
    expect(f.validations, 2);
  });

  testWidgets(
    'caption copying is an explicit separate action and never sends an image',
    (tester) async {
      final f = _Fixture();
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            clipboard = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await f.mount(tester);
      await f.tap(tester, 'feed-share-copy-caption');
      expect(clipboard, '오늘 함께 걸었던 바다.');
      expect(f.shares, 0);
      expect(f.links, 0);
      expect(f.validations, 2);
    },
  );

  testWidgets(
    'failed rendering can retry and never falls back to an unselected photo',
    (tester) async {
      final f = _Fixture();
      f.renderer = (_) async =>
          throw const FormatException('unavailable original');
      await f.mount(tester, initialPhotoId: 'second');
      expect(f.rendered, ['second']);
      expect(f.shares, 0);
      f.renderer = (_) async => f.second;
      await f.tap(tester, 'feed-share-retry');
      await f.tap(tester, 'feed-share-image');
      expect(f.shared, orderedEquals(f.second));
      expect(f.rendered, ['second', 'second']);
    },
  );

  testWidgets('share controls remain reachable at 320px with dark large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = _Fixture();
    await f.mount(tester, darkLarge: true);
    await tester.ensureVisible(find.byKey(const ValueKey('feed-share-image')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await f.tap(tester, 'feed-share-close');
    expect(find.byKey(const ValueKey('open-share')), findsOneWidget);
  });
}
