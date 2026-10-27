import 'package:flutter/services.dart';

Future<void> loadMomentCaptureFonts() async {
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  for (final family in ['Pretendard', 'NotoSansKR', 'NotoSans']) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'));
    await loader.load();
  }
}
