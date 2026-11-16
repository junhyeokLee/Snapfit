import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_curation.dart';

PremiumTemplate _design(int id) => PremiumTemplate(
  id: id,
  title: '컬렉션 $id',
  category: '여행',
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 24,
  userCount: 0,
  templateJson:
      '{"designWidth":500,"designHeight":500,"pages":[{"layers":[]}]}',
);

void main() {
  testWidgets(
    'lazy curation restores only its page cursor and resets changed admin order',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bucket = PageStorageBucket();
      final templates = [_design(1001), _design(1002), _design(1003)];
      var visible = true;
      var order = [
        'template:server-1001',
        'template:server-1002',
        'template:server-1003',
      ];
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          theme: SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    change = setState;
                    return visible
                        ? TemplateCuration(
                            templates: templates,
                            selection: StoreCuration(
                              placement: 'templates',
                              title: '컬렉션',
                              subtitle: '',
                              productKeys: order,
                            ),
                            onOpen: (_) {},
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final position = find.byKey(const ValueKey('curation-position'));
      final next = find.byTooltip('다음 컬렉션');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(position).data, '03 / 03');
      final originalController = tester
          .widget<PageView>(find.byKey(const ValueKey('curation-pager')))
          .controller;

      // Removing the subtree models the lazy interlude leaving the sliver cache.
      change(() => visible = false);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateCuration), findsNothing);
      change(() => visible = true);
      await tester.pumpAndSettle();
      final restoredController = tester
          .widget<PageView>(find.byKey(const ValueKey('curation-pager')))
          .controller!;
      expect(restoredController, isNot(same(originalController)));
      expect(restoredController.page, closeTo(2, .001));
      expect(tester.widget<Text>(position).data, '03 / 03');

      change(() => order = [order.last, order.first]);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(position).data, '01 / 02');
      expect(restoredController.page, closeTo(0, .001));
      change(() => visible = false);
      await tester.pumpAndSettle();
      change(() => visible = true);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(position).data, '01 / 02');
      expect(tester.takeException(), isNull);
    },
  );
}
