import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_sticker_tab.dart';

class MaterialPreview extends StatefulWidget {
  const MaterialPreview({super.key});

  @override
  State<MaterialPreview> createState() => _MaterialPreviewState();
}

class _MaterialPreviewState extends State<MaterialPreview> {
  StudioDecorationSpec _selected = studioDecorations.first;
  Color _background = const Color(0xFFE5E9E4);
  String? _legacy;
  StudioWordArt? get _wordArt => _legacy?.startsWith('wordart:') == true
      ? studioWordArtById(_legacy!.substring(8))
      : null;
  String get _label =>
      _wordArt?.label ?? (_legacy == null ? _selected.label : '기존 장식');

  Widget _artwork() {
    final value = _legacy;
    if (_wordArt case final art?) return StudioWordArtPreview(art: art);
    if (value == null) return StudioDecoration(spec: _selected);
    if (value.startsWith('asset:')) {
      return Image.asset(value.substring(6), fit: BoxFit.contain);
    }
    if (value.startsWith('deco:')) {
      return LayerBuilder.buildStickerDecoration(
        style: value.substring(5).split('@').first,
        width: 240,
        height: 240,
      );
    }
    return FittedBox(child: Text(value, style: const TextStyle(fontSize: 120)));
  }

  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('종이와 스티커', style: TextStyle(fontSize: 16)),
        toolbarHeight: 48,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final art = ColoredBox(
              color: _background,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(36, 16, 36, 8),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio:
                              _wordArt?.sourceSize.aspectRatio ??
                              (_legacy == null ? _selected.aspectRatio : 1),
                          child: Semantics(
                            label: '$_label 크게 보기',
                            child: RepaintBoundary(child: _artwork()),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _label,
                          style: TextStyle(
                            fontSize: 13,
                            color: _background.computeLuminance() < .3
                                ? Colors.white
                                : const Color(0xFF293B30),
                          ),
                        ),
                        const SizedBox(width: 16),
                        for (final entry in const {
                          '화이트': Color(0xFFFCFCF8),
                          '세이지': Color(0xFFE5E9E4),
                          '잉크': Color(0xFF26352E),
                        }.entries)
                          IconButton(
                            tooltip: entry.key,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: const EdgeInsets.all(5),
                            onPressed: () =>
                                setState(() => _background = entry.value),
                            icon: Container(
                              width: 23,
                              height: 23,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: entry.value,
                                border: Border.all(
                                  color: _background == entry.value
                                      ? const Color(0xFF72977D)
                                      : const Color(0x668B968E),
                                  width: _background == entry.value ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            final picker = DecorateStickerTab(
              surfaceColor: Theme.of(context).colorScheme.surface,
              onStickerTap: (value) {
                final item = studioDecorations
                    .where((item) => item.insertionValue == value)
                    .firstOrNull;
                setState(() {
                  _legacy = item == null ? value : null;
                  if (item != null) _selected = item;
                });
              },
            );
            return landscape
                ? Row(
                    children: [
                      Expanded(flex: 5, child: art),
                      Expanded(flex: 6, child: picker),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 4, child: art),
                      Expanded(flex: 6, child: picker),
                    ],
                  );
          },
        ),
      ),
    ),
  );
}
