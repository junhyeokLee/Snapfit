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

// Local collection workbench. No credentials, AI requests or publishing.
void main() => runApp(const TemplatePreviewWorkbench());

class TemplatePreviewWorkbench extends StatelessWidget {
  const TemplatePreviewWorkbench({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SnapFit · 템플릿 스튜디오',
      initialRoute: Uri.base.queryParameters['studio'] == 'atelier'
          ? '/atelier'
          : Uri.base.queryParameters['catalog'] == 'store'
          ? '/store'
          : Uri.base.queryParameters['frames'] == 'true'
          ? '/frames'
          : switch (Uri.base.queryParameters['collection']) {
              'wind-atlas' => '/wind-atlas',
              'our-prose' => '/our-prose',
              'luminous-edition' => '/luminous-edition',
              'journey' => '/journey',
              'small-days' => '/small-days',
              final id when FreeCollectionVolume.byId(id ?? '') != null =>
                '/$id',
              _ => '/',
            },
      routes: {
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
        '/materials': (_) => const MaterialPreview(),
        '/atelier': (_) => const AtelierPreview(),
        '/wind-atlas': (_) => const WindAtlasPreview(),
        '/our-prose': (_) => const ProseStudyPreview(),
        '/luminous-edition': (_) => const LuminousEditionPreview(),
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
