import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'editorial_preview.dart';
import 'frame_preview.dart';
import 'free_collection_preview.dart';
import 'lightbound_preview.dart';
import 'material_preview.dart';
import 'atelier_preview.dart';
import 'wind_atlas_preview.dart';
import 'prose_study_preview.dart';
import 'luminous_edition_preview.dart';
import 'heirloom_preview.dart';
import 'concept_volume_preview.dart';
import 'luminous_materials.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';

// Local collection workbench. No credentials, AI requests or publishing.
void main() => runApp(const TemplatePreviewWorkbench());

class TemplatePreviewWorkbench extends StatelessWidget {
  const TemplatePreviewWorkbench({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SnapFit · 템플릿 스튜디오',
      initialRoute: Uri.base.queryParameters['materials'] == 'keepsake'
          ? '/keepsake-materials'
          : Uri.base.queryParameters['studio'] == 'atelier'
          ? '/atelier'
          : Uri.base.queryParameters['catalog'] == 'premium'
          ? '/premium-studies'
          : Uri.base.queryParameters['catalog'] == 'store'
          ? '/store'
          : Uri.base.queryParameters['frames'] == 'true'
          ? '/frames'
          : switch (Uri.base.queryParameters['collection']) {
              'wind-atlas' => '/wind-atlas',
              'our-prose' => '/our-prose',
              'luminous-edition' => '/luminous-edition',
              'travel-keepsake-20' => '/travel-keepsake-20',
              'journey' => '/journey',
              'small-days' => '/small-days',
              final id when ConceptVolume.byId(id ?? '') != null => '/$id',
              final id when HeirloomStudy.byId(id ?? '') != null => '/$id',
              final id when FreeCollectionVolume.byId(id ?? '') != null =>
                '/$id',
              _ => '/',
            },
      routes: {
        '/premium-studies': (_) => const PremiumStudiesCatalog(),
        for (final volume in ConceptVolume.values)
          '/${volume.id}': (_) => ConceptVolumePreview(volume: volume),
        for (final study in HeirloomStudy.values)
          '/${study.id}': (_) => HeirloomPreview(study: study),
        '/store': (_) => ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, __) => const StoreScreen(),
        ),
        '/lightbound': (_) => const LightboundPreview(),
        for (final volume in EditorialVolume.values)
          '/${volume.route}': (_) => EditorialPreview(volume: volume),
        for (final volume in FreeCollectionVolume.values)
          '/${volume.id}': (_) => FreeCollectionPreview(volume: volume),
        '/frames': (_) => const FramePreview(),
        '/keepsake-materials': (_) => const LuminousMaterials(newOnly: true),
        '/materials': (_) => ProviderScope(
          // Isolated local workbench only; never reaches the purchase backend.
          overrides: [
            pointShopAccessGateProvider.overrideWithValue(
              (context, ref, {required productKey, required title}) async =>
                  true,
            ),
            pointShopCatalogProvider.overrideWith((ref) async => []),
            ownedPointShopKeysProvider.overrideWith((ref) async => {}),
          ],
          child: const MaterialPreview(),
        ),
        '/atelier': (_) => const AtelierPreview(),
        '/wind-atlas': (_) => const WindAtlasPreview(),
        '/our-prose': (_) => const ProseStudyPreview(),
        '/luminous-edition': (_) => const LuminousEditionPreview(),
        '/travel-keepsake-20': (_) => const TravelKeepsakeArchivePreview(),
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSans',
        colorSchemeSeed: SnapFitColors.accent,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LightboundPreview(),
    ),
  );
}
