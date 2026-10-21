import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> selectStoreCatalog(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('store-department-$index')));
  await tester.pumpAndSettle();
}
