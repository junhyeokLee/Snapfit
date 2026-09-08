import 'package:flutter/material.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';

class FramePreview extends StatefulWidget {
  const FramePreview({super.key});

  @override
  State<FramePreview> createState() => _FramePreviewState();
}

class _FramePreviewState extends State<FramePreview> {
  String _style = 'studioDoubleMat';
  CollectionAspect _aspect = CollectionAspect.portrait;
  String _photo = 'petal_couple';
  Color _background = const Color(0xFFE9EDEB);
  final _undo = <String>[];
  final _redo = <String>[];
  static const _photos = {
    'petal_couple': '정원의 두 사람',
    'travel_harbor': '여행의 풍경',
    'daily_desk': '일상의 취향',
  };

  Widget _image({int width = 900}) => Image.asset(
    'assets/templates/original_editorial/images/$_photo.png',
    fit: BoxFit.cover,
    cacheWidth: width,
  );

  void _select(String key) {
    if (!imageFrameStyles.any((style) => style.key == key) || key == _style)
      return;
    setState(() {
      _undo.add(_style);
      _redo.clear();
      _style = key;
    });
  }

  Widget _artwork() {
    if (_style.isEmpty || StudioMaterial.photoStyles.contains(_style)) {
      return StudioMaterial(style: _style, child: _image());
    }
    final size = _aspect.canvas;
    return LayoutBuilder(
      builder: (context, constraints) => TemplatePageRenderer(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        designCanvasSize: size,
        layers: [
          LayerModel(
            id: 'frame-inspection',
            type: LayerType.image,
            position: Offset.zero,
            width: size.width,
            height: size.height,
            imageBackground: _style,
            imageUrl:
                'asset:assets/templates/original_editorial/images/$_photo.png',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        surfaceTintColor: Colors.transparent,
        title: const Text('사진 프레임', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: '실행 취소',
            icon: const Icon(Icons.undo_rounded, size: 22),
            onPressed: _undo.isEmpty
                ? null
                : () => setState(() {
                    _redo.add(_style);
                    _style = _undo.removeLast();
                  }),
          ),
          IconButton(
            tooltip: '다시 실행',
            icon: const Icon(Icons.redo_rounded, size: 22),
            onPressed: _redo.isEmpty
                ? null
                : () => setState(() {
                    _undo.add(_style);
                    _style = _redo.removeLast();
                  }),
          ),
          IconButton(
            tooltip: '편집기 프레임 선택창',
            icon: const Icon(Icons.photo_size_select_large_rounded, size: 22),
            onPressed: () async {
              final key = await ImageFrameStylePicker.show(
                context,
                currentKey: _style,
                photoAspectRatio: _aspect.canvas.aspectRatio,
                photoBuilder: (_) => _image(width: 360),
              );
              if (mounted && key != null) _select(key);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 650;
            final art = ColoredBox(
              color: _background,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 40 : 36,
                        vertical: 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 650),
                          child: AspectRatio(
                            aspectRatio: _aspect.canvas.aspectRatio,
                            child: Semantics(
                              key: ValueKey('$_style-${_aspect.name}'),
                              label:
                                  '${imageFrameStyles.firstWhere((s) => s.key == _style).label} 크게 보기',
                              image: true,
                              child: RepaintBoundary(child: _artwork()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final entry in const {
                          '화이트 배경': Color(0xFFFAFAFA),
                          '세이지 배경': Color(0xFFE9EDEB),
                          '차콜 배경': Color(0xFF303738),
                        }.entries)
                          IconButton(
                            tooltip: entry.key,
                            onPressed: () =>
                                setState(() => _background = entry.value),
                            icon: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: entry.value,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: _background == entry.value ? 3 : 1,
                                  color: _background == entry.value
                                      ? SnapFitColors.accent
                                      : const Color(0xFF969F9A),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        for (final entry in _photos.entries)
                          IconButton(
                            tooltip: entry.value,
                            onPressed: () => setState(() => _photo = entry.key),
                            icon: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _photo == entry.key
                                      ? SnapFitColors.accent
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Image.asset(
                                'assets/templates/original_editorial/images/${entry.key}.png',
                                fit: BoxFit.cover,
                                cacheWidth: 90,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            final picker = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: SegmentedButton<CollectionAspect>(
                    expandedInsets: EdgeInsets.zero,
                    segments: const [
                      ButtonSegment(
                        value: CollectionAspect.portrait,
                        label: Text('세로'),
                      ),
                      ButtonSegment(
                        value: CollectionAspect.square,
                        label: Text('정사각'),
                      ),
                      ButtonSegment(
                        value: CollectionAspect.landscape,
                        label: Text('가로'),
                      ),
                    ],
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    selected: {_aspect},
                    onSelectionChanged: (selection) =>
                        setState(() => _aspect = selection.single),
                  ),
                ),
                Expanded(
                  child: CatalogFavoriteGrid<String>(
                    items: StudioMaterial.photoStyles.toList(),
                    keyOf: CatalogFavoriteKeys.frame,
                    labelOf: (key) =>
                        imageFrameStyles.firstWhere((s) => s.key == key).label,
                    mainAxisExtent: 194,
                    itemBuilder: (context, key) {
                      final selected = key == _style;
                      final label = imageFrameStyles
                          .firstWhere((s) => s.key == key)
                          .label;
                      return Semantics(
                        label: label,
                        button: true,
                        selected: selected,
                        excludeSemantics: true,
                        onTap: () => _select(key),
                        child: Material(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: selected
                                  ? SnapFitColors.accent
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _select(key),
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      44,
                                      12,
                                      12,
                                    ),
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: _aspect.canvas.aspectRatio,
                                        child: StudioMaterial(
                                          style: key,
                                          child: _image(width: 360),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
            return wide
                ? Row(
                    children: [
                      Expanded(child: art),
                      SizedBox(width: 340, child: picker),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 5, child: art),
                      Expanded(flex: 6, child: picker),
                    ],
                  );
          },
        ),
      ),
    ),
  );
}
