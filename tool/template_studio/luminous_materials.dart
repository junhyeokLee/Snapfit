import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';

class LuminousMaterials extends StatefulWidget {
  const LuminousMaterials({super.key, this.newOnly = false});
  final bool newOnly;
  @override
  State<LuminousMaterials> createState() => _LuminousMaterialsState();
}

class _LuminousMaterialsState extends State<LuminousMaterials> {
  String? _collection;
  int get recentMaterialCount =>
      conceptWaveDecorations.length +
      atelierCompositionDecorations.length +
      keepsakeDecorations.length +
      keepsakePhotoFrames.length +
      atelierEditionPhotoFrames.length +
      atelierWordArts.length;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    initialIndex: widget.newOnly ? 1 : 0,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.newOnly ? '재료 라이브러리 $recentMaterialCount' : '꾸밈 재료',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: '재료 편집 미리보기',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.pushNamed(context, '/materials'),
          ),
        ],
        bottom: TabBar(
          tabs: [
            Tab(text: '스티커·종이'),
            Tab(text: '프레임'),
            const Tab(text: '문구'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final label in <String?>[
                        null,
                        ...keepsakeMaterialCollections,
                        ...atelierCompositionCollections,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label ?? '전체'),
                            selected: _collection == label,
                            onSelected: (_) =>
                                setState(() => _collection = label),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _grid(context, [
                    for (final s
                        in [
                          ...conceptWaveDecorations,
                          ...atelierCompositionDecorations,
                          ...keepsakeDecorations,
                          if (!widget.newOnly) ...[
                            ...zineDecorations,
                            ...luminousDecorations,
                            ...travelDecorations,
                            ...heirloomDecorations,
                            ...vowEditionDecorations,
                          ],
                        ].where(
                          (s) =>
                              _collection == null ||
                              s.collection == _collection,
                        ))
                      _Piece(
                        'decoration:${s.id}',
                        s.label,
                        () => Center(
                          child: AspectRatio(
                            aspectRatio: s.aspectRatio,
                            child: StudioDecoration(spec: s),
                          ),
                        ),
                      ),
                  ]),
                ),
              ],
            ),
            _grid(context, [
              for (final s
                  in [
                    ...atelierEditionFrameStyles,
                    ...imageFrameStyles.where(
                      (s) => !atelierEditionPhotoFrames.contains(s.key),
                    ),
                  ].where(
                    (s) =>
                        keepsakePhotoFrames.contains(s.key) ||
                        atelierEditionPhotoFrames.contains(s.key) ||
                        (!widget.newOnly && editionPhotoFrames.contains(s.key)),
                  ))
                _Piece(
                  'frame:${s.key}',
                  s.label,
                  () => StudioMaterial(
                    style: s.key,
                    child: Image.asset(
                      'assets/templates/original_editorial/images/petal_evening.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ]),
            _grid(context, [
              for (final s in widget.newOnly ? atelierWordArts : studioWordArts)
                _Piece(
                  s.favoriteKey,
                  s.label,
                  () => StudioWordArtPreview(art: s),
                ),
            ]),
          ],
        ),
      ),
    ),
  );
  Widget _grid(BuildContext context, List<_Piece> items) =>
      CatalogFavoriteGrid<_Piece>(
        items: items,
        keyOf: (s) => s.keyName,
        labelOf: (s) => s.label,
        mainAxisExtent: MediaQuery.sizeOf(context).height < 480 ? 176 : 236,
        maxCrossAxisExtent: 260,
        itemBuilder: (context, s) => Semantics(
          button: true,
          label: '${s.label} 확대',
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: Text(s.label, style: const TextStyle(fontSize: 17)),
                  ),
                  body: SafeArea(
                    child: InteractiveViewer(
                      maxScale: 4,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 700,
                            maxHeight: 700,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: s.build(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
                    child: s.build(),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Center(
                    child: Text(s.label, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Piece {
  const _Piece(this.keyName, this.label, this.build);
  final String keyName, label;
  final Widget Function() build;
}
