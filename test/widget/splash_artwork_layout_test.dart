import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/onboarding/data/first_visit_store.dart';
import 'package:snap_fit/features/splash/presentation/views/splash_screen.dart';

class _PendingAuth extends AuthViewModel {
  _PendingAuth(this.result);

  final Future<UserInfo?> result;

  @override
  Future<UserInfo?> build() => result;
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  Size size,
) async {
  const folder = String.fromEnvironment('SPLASH_CAPTURE_DIR');
  if (kIsWeb || folder.isEmpty) return;
  final render =
      boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Splash capture produced no PNG');
      final file = File(
        '$folder/native-splash-${size.width.toInt()}x${size.height.toInt()}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      PreferencesFirstVisitStore.key: 3,
    }),
  );

  for (final size in [
    const Size(390, 844),
    const Size(360, 800),
    const Size(360, 640),
    const Size(768, 1024),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'actual splash artwork decodes and covers $size without changing routes',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final auth = Completer<UserInfo?>();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authViewModelProvider.overrideWith(
                () => _PendingAuth(auth.future),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: RepaintBoundary(key: boundary, child: const SplashScreen()),
            ),
          ),
        );
        await tester.pump();
        final finder = find.descendant(
          of: find.byType(SplashScreen),
          matching: find.byType(Image),
        );
        final image = tester.widget<Image>(finder);
        final landscape = size.width > size.height;
        expect(
          (image.image as AssetImage).assetName,
          landscape
              ? 'assets/brand/album-mark/splash-landscape.png'
              : 'assets/splash.png',
        );
        expect(image.fit, BoxFit.cover);
        expect(
          image.alignment,
          landscape ? Alignment.center : Alignment.topCenter,
        );
        expect(image.gaplessPlayback, isTrue);
        expect(image.semanticLabel, '사진이 한 권의 앨범으로 모이는 스냅핏');
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          SnapFitColors.accent,
        );

        Object? decodeError;
        await tester.runAsync(
          () => precacheImage(
            image.image,
            tester.element(finder),
            onError: (error, _) => decodeError = error,
          ),
        );
        await tester.pumpAndSettle();
        expect(decodeError, isNull);
        final raw = tester.widget<RawImage>(
          find.descendant(of: finder, matching: find.byType(RawImage)),
        );
        expect(raw.image, isNotNull);
        expect(raw.image!.width, greaterThan(0));
        expect(raw.image!.height, greaterThan(0));
        expect(tester.getSize(finder), size);
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(auth.isCompleted, isFalse);
        expect(tester.takeException(), isNull);
        await _capture(tester, boundary, size);

        await tester.pumpWidget(const SizedBox.shrink());
        auth.complete(null);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
      skip: kIsWeb,
    );
  }
}
