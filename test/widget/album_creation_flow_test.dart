import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import '../helpers/mock_repositories.dart';
import 'ai_album_start_step_test.dart' show wrapCreation;

PremiumTemplate _catalogTemplate(bool premium) => PremiumTemplate(
  id: 99001,
  title: '여행 디자인',
  coverImageUrl: '',
  previewImages: [],
  pageCount: 2,
  userCount: 0,
  isPremium: premium,
  templateJson: jsonEncode({
    'designWidth': 500,
    'designHeight': 500,
    'cover': {
      'layers': [
        {
          'id': 'cover-photo',
          'type': 'IMAGE',
          'x': .1,
          'y': .1,
          'width': .8,
          'height': .8,
          'payload': {'imageUrl': 'asset:assets/snapfit_home_square.jpg'},
        },
      ],
    },
    'pages': List.generate(
      2,
      (i) => {
        'layers': [
          {
            'id': 'photo-$i',
            'type': 'IMAGE',
            'x': .1,
            'y': .1,
            'width': .8,
            'height': .8,
          },
        ],
      },
    ),
  }),
);

void main() {
  for (final premium in [false, true]) {
    testWidgets(
      'allowed catalog selection premium=$premium uses price-neutral source copy',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final template = _catalogTemplate(premium);
        final repo = MockTemplateRepository();
        stubGetTemplates(repo, [template]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              albumCreationCatalogProvider.overrideWith(
                (ref) => Stream.value([template]),
              ),
              templateRepositoryProvider.overrideWithValue(repo),
            ],
            child: wrapCreation(const AlbumCreateFlowScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('creation-template-99001')),
        );
        await tester.tap(find.byKey(const ValueKey('creation-template-99001')));
        await tester.pumpAndSettle();
        final preview = tester.widget<CreationTemplatePreview>(
          find.byType(CreationTemplatePreview),
        );
        expect(preview.pages.length, 3);
        expect(preview.pages.first.single.id, 'cover-photo');
        await tester.tap(find.text('이 디자인 선택'));
        await tester.pumpAndSettle();
        expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
        final setup = tester.widget<AlbumCreateStep1>(
          find.byType(AlbumCreateStep1),
        );
        expect(setup.sourceLabel, '선택한 템플릿');
        expect(setup.minPageCount, 2);
        expect(
          setup.coverLayers!
              .where((l) => l.type == LayerType.image)
              .single
              .imageUrl,
          isNull,
        );
        final hard = find.byKey(const ValueKey('print-cover-hard'));
        await tester.ensureVisible(hard);
        await tester.tap(hard);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('시작 방식 변경'));
        await tester.tap(find.byTooltip('시작 방식 변경'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('creation-template-99001')),
        );
        await tester.tap(find.byKey(const ValueKey('creation-template-99001')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('이 디자인 선택'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
              .selectedCover!
              .coverType,
          PrintCoverType.hard,
        );
        await tester.tap(find.text('사진 채우기'));
        await tester.pumpAndSettle();
        expect(find.byType(TemplatePhotoFillStep), findsOneWidget);
        expect(
          tester
              .widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep))
              .pages
              .length,
          3,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
