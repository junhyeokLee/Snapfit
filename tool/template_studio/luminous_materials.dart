import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/edition_photo_frame.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';

class LuminousMaterials extends StatelessWidget {
  const LuminousMaterials({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('꾸밈 재료', style: TextStyle(fontSize: 18)),
        bottom: const TabBar(
          tabs: [
            Tab(text: '스티커·종이'),
            Tab(text: '프레임'),
            Tab(text: '문구'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          children: [
            _grid(context, [
              for (final s in [...zineDecorations, ...luminousDecorations])
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
            _grid(context, [
              for (final s in imageFrameStyles.where(
                (s) => editionPhotoFrames.contains(s.key),
              ))
                _Piece(
                  'frame:${s.key}',
                  s.label,
                  () => EditionPhotoFrame(
                    style: s.key,
                    child: Image.asset(
                      'assets/templates/original_editorial/images/petal_evening.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ]),
            _grid(context, [
              for (final s in studioWordArts)
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
