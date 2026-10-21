import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/template_design_profile.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_design_profile_summary.dart';

String _document({int innerPages = 2}) => jsonEncode({
  'designWidth': 500,
  'designHeight': 500,
  'pages': [
    {
      'layers': [
        {
          'id': 'cover-photo',
          'type': 'image',
          'x': 0,
          'y': 0,
          'width': 500,
          'height': 500,
        },
      ],
    },
    for (var index = 0; index < innerPages; index++)
      {
        'layers': [
          {
            'id': '${index}_photo',
            'type': 'image',
            'x': 20,
            'y': 20,
            'width': 460,
            'height': 320,
          },
          {
            'id': '${index}_body',
            'type': 'text',
            'typographyRole': 'body',
            'text': '이날의 기록',
            'x': 20,
            'y': 360,
            'width': 460,
            'height': 100,
          },
        ],
      },
  ],
});

PremiumTemplate _template({
  int id = 701,
  String? source,
  String Function()? builder,
}) => PremiumTemplate(
  id: id,
  title: '살펴본 디자인 $id',
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 999,
  userCount: 0,
  templateJson: source,
  documentBuilder: builder,
);

Widget _wrap(Widget child, {double scale = 1, bool dark = false}) =>
    ProviderScope(
      overrides: [
        pointShopCatalogProvider.overrideWith((_) async => []),
        ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: child,
        ),
      ),
    );

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'summary reports current contents and explains cover photo slots',
    (tester) async {
      final template = _template(source: _document());
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: TemplateDesignProfileSummary(
              profile: TemplateDesignProfile.of(template),
            ),
          ),
        ),
      );
      expect(find.text('내지 2쪽 · 사진 넣는 3곳'), findsOneWidget);
      expect(find.text('글쓰기 2쪽 · 본문이 있는 내지 기준'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing document remains unknown at narrow width and large text',
    (tester) async {
      _setViewport(tester, const Size(256, 600));
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SingleChildScrollView(
              child: TemplateDesignProfileSummary(
                profile: TemplateDesignProfile.of(_template(source: '{')),
              ),
            ),
          ),
          scale: 2,
          dark: true,
        ),
      );
      expect(find.text('사진 구성 확인 필요 · 쪽수 확인 필요'), findsOneWidget);
      expect(find.text('내지 구성 확인 필요'), findsOneWidget);
      expect(find.textContaining('0곳'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(844, 320),
    const Size(390, 400),
  ]) {
    testWidgets('creation inspection keeps facts and action usable at $size', (
      tester,
    ) async {
      _setViewport(tester, size);
      var uses = 0;
      await tester.pumpWidget(
        _wrap(
          CreationTemplatePreview(
            title: '긴 제목이 있는 가족 여행 디자인',
            isPremium: false,
            pages: const <List<LayerModel>>[[], [], []],
            canvas: const Size(500, 500),
            profileSummary: TemplateDesignProfileSummary(
              profile: TemplateDesignProfile.of(_template(source: _document())),
            ),
            onUse: () => uses++,
            onRetry: () {},
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('내지 2쪽 · 사진 넣는 3곳'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('creation_document_position')),
            )
            .data,
        isNot('표지'),
      );
      final use = find.widgetWithText(FilledButton, '이 디자인 선택');
      final action = tester.getRect(use);
      expect(action.top, greaterThanOrEqualTo(0));
      expect(action.bottom, lessThanOrEqualTo(size.height));
      await tester.tap(use);
      expect(uses, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('native creation detail receives the edition actually supplied', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _wrap(
        TemplateDetailScreen(
          template: _template(source: _document(innerPages: 4)),
          selectForCreation: true,
          guestPreview: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('creation-template-profile')),
      findsOneWidget,
    );
    expect(find.text('내지 4쪽 · 사진 넣는 5곳'), findsOneWidget);
    expect(find.text('글쓰기 4쪽 · 본문이 있는 내지 기준'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'creation catalog reads a profile only after inspecting one design',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      final reads = List<int>.filled(68, 0);
      final source = _document();
      final templates = [
        for (var index = 0; index < 68; index++)
          _template(
            id: 1000 + index,
            builder: () {
              reads[index]++;
              return source;
            },
          ),
      ];
      PremiumTemplate? selected;
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: AiAlbumStartStep(
              onAiStart: () {},
              onManualStart: () {},
              templates: AsyncData(templates),
              onTemplateSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('creation-inspected-profile')),
        findsNothing,
      );
      final first = find.byKey(const ValueKey('creation-template-1000'));
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      final before = [...reads];
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(selected, same(templates.first));
      expect(
        find.byKey(const ValueKey('creation-inspected-profile')),
        findsOneWidget,
      );
      expect(reads.first, before.first + 1);
      expect(reads.skip(1).toList(), before.skip(1).toList());
      expect(tester.takeException(), isNull);
    },
  );
}
