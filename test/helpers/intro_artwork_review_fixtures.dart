import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';

import 'first_visit_fixtures.dart';

/// Counts real image-buffer requests, including cache misses hidden by a warm
/// golden-test setup. Optional gates model a slow decode during rapid closing.
class IntroReviewAssetBundle extends CachingAssetBundle {
  final bufferLoads = <String, int>{};
  final _gates = <String, Completer<void>>{};

  void block(String path) => _gates[path] = Completer<void>();

  void releaseAll() {
    for (final gate in _gates.values) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    bufferLoads.update(key, (n) => n + 1, ifAbsent: () => 1);
    if (_gates[key] case final gate?) await gate.future;
    return rootBundle.loadBuffer(key);
  }
}

Widget introReviewApp({
  required IntroReviewAssetBundle bundle,
  required Widget home,
  bool dark = false,
}) => ProviderScope(
  overrides: [
    firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(3)),
  ],
  child: MaterialApp(
    theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
    builder: (_, child) => DefaultAssetBundle(bundle: bundle, child: child!),
    home: home,
  ),
);

String introReviewImagePath(Image widget) =>
    ((widget.image as ResizeImage).imageProvider as AssetImage).assetName;

Future<void> loadIntroReviewImages(WidgetTester tester) async {
  final context = tester.element(find.byType(AppIntroductionScreen));
  final providers = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .toSet();
  await tester.runAsync(() async {
    for (final provider in providers) {
      await precacheImage(provider, context);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> showIntroReviewPage(WidgetTester tester, int page) async {
  await tester.tap(find.byKey(ValueKey('intro-page-$page')));
  await tester.pumpAndSettle();
}
