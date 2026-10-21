import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_links is the sole native custom URL handler on Android and iOS', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      RegExp(
        r'<meta-data\s+android:name="flutter_deeplinking_enabled"\s+android:value="false"\s*/>',
      ).hasMatch(android),
      true,
    );
    expect(android, contains('android:scheme="snapfit"'));
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(
        r'<key>FlutterDeepLinkingEnabled</key>\s*<false\s*/>',
      ).hasMatch(ios),
      true,
    );
    expect(ios, contains('<string>snapfit</string>'));
  });
}
