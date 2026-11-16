import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_saved_works_screen.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/helpers/load_moment_capture_fonts.dart';

class _Client extends Mock implements HttpClient {}

class _Request extends Mock implements HttpClientRequest {}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _author = SocialProfile(
  userId: 'local-gallery-creator',
  displayName: '서연의 사진 기록',
  handle: 'seoyeon.archive',
);

List<SocialWork> get _works => [
  SocialWork(
    id: 'gallery-jeju',
    title: '바람이 머문 제주',
    author: _author,
    topic: '여행',
    aspectRatio: 1.5,
    imageUrls: const ['https://fixture.invalid/jeju.jpg'],
    createdAt: DateTime(2026, 10, 26),
  ),
  SocialWork(
    id: 'gallery-summer',
    title: '오래 기억할 여름',
    author: _author,
    topic: '일상',
    aspectRatio: 1,
    imageUrls: const ['https://fixture.invalid/summer.jpg'],
    createdAt: DateTime(2026, 10, 25),
  ),
];

void main() {
  setUpAll(() async {
    registerFallbackValue(Uri.parse('https://fixture.invalid'));
    if (Platform.environment['SNAPFIT_CAPTURE_SAVED_ALBUM'] != null) {
      await loadMomentCaptureFonts();
    }
  });

  testWidgets('capture saved works with local photos and actual typeface', (
    tester,
  ) async {
    final output = Platform.environment['SNAPFIT_CAPTURE_SAVED_ALBUM']!;
    final photos = <String, Uint8List>{};
    for (final entry in <String, String>{
      'jeju.jpg':
          'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg',
      'summer.jpg': 'assets/snapfit_home_square.jpg',
    }.entries) {
      photos[entry.key] = (await tester.runAsync(() => rootBundle.load(entry.value)))!.buffer.asUint8List();
    }
    final client = _Client();
    when(() => client.getUrl(any())).thenAnswer((invocation) async {
      final uri = invocation.positionalArguments.first as Uri;
      final request = _Request();
      when(
        () => request.close(),
      ).thenAnswer((_) async => _Response(photos[uri.pathSegments.last]!));
      return request;
    });
    final previous = painting.debugNetworkImageHttpClientProvider;
    painting.debugNetworkImageHttpClientProvider = () => client;
    addTearDown(() {
      painting.debugNetworkImageHttpClientProvider = previous;
      painting.PaintingBinding.instance.imageCache.clear();
      painting.PaintingBinding.instance.imageCache.clearLiveImages();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    try {
      for (final entry in <(String, Size, bool)>[
        ('phone-light', const Size(390, 844), false),
        ('desktop-light', const Size(1365, 950), false),
        ('phone-dark', const Size(390, 1000), true),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = entry.$2;
        tester.view.devicePixelRatio = 1;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              socialCurrentUserIdProvider.overrideWithValue(
                'local-gallery-owner',
              ),
              socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
              socialSavedWorksPageProvider.overrideWith(
                (_, _) async => SocialWorkPage(
                  items: _works,
                  hasMore: false,
                  nextOffset: 2,
                ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: entry.$3 ? SnapFitTheme.dark() : SnapFitTheme.light(),
              home: RepaintBoundary(
                key: boundary,
                child: const SocialSavedWorksScreen(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        for(var frame=0;frame<200;frame++) {
          await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:10)));
          await tester.pump(const Duration(milliseconds:40));
          if(frame>15 && PaintingBinding.instance.imageCache.pendingImageCount==0) break;
        }
        await tester.pumpAndSettle();
        expect(find.text('바람이 머문 제주'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('$output/saved-gallery-${entry.$1}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      painting.debugNetworkImageHttpClientProvider = previous;
      painting.PaintingBinding.instance.imageCache.clear();
      painting.PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }, skip: Platform.environment['SNAPFIT_CAPTURE_SAVED_ALBUM'] == null);
}
