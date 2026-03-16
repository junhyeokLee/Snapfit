import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/premium_template_list.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows loading indicator while templates load', (tester) async {
    final completer = Completer<List<PremiumTemplate>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((ref) async {
            return completer.future;
          }),
        ],
        child: _wrap(const PremiumTemplateList()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error text when templates fail to load', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((ref) async {
            throw Exception('fail');
          }),
        ],
        child: _wrap(const PremiumTemplateList()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('템플릿을 불러올 수 없습니다.'), findsOneWidget);
  });

  testWidgets('renders nothing when templates are empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((ref) async => const <PremiumTemplate>[]),
        ],
        child: _wrap(const PremiumTemplateList()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
  });
}
