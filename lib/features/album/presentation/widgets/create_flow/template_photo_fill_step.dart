import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../domain/entities/layer.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';

class TemplatePhotoFillStep extends ConsumerStatefulWidget {
  const TemplatePhotoFillStep({
    super.key,
    required this.pages,
    required this.cover,
    required this.onChanged,
    required this.onContinue,
    this.pickPhoto,
    this.preserveTypography = false,
  });
  final List<List<LayerModel>> pages;
  final CoverSize cover;
  final ValueChanged<List<List<LayerModel>>> onChanged;
  final VoidCallback onContinue;
  final Future<AssetEntity?> Function()? pickPhoto;
  final bool preserveTypography;

  @override
  ConsumerState<TemplatePhotoFillStep> createState() =>
      _TemplatePhotoFillStepState();
}

class _TemplatePhotoFillStepState extends ConsumerState<TemplatePhotoFillStep> {
  int _page = 0;
  bool _picking = false;
  final Map<String, File> _files = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    for (var page = 0; page < widget.pages.length; page++) {
      for (final layer in widget.pages[page]) {
        if (layer.asset == null) continue;
        final file = await layer.asset!.file;
        if (!mounted) return;
        if (file != null) setState(() => _files['$page:${layer.id}'] = file);
      }
    }
  }

  Future<void> _pick(int page, String id) async {
    if (_picking) return;
    final index = widget.pages[page].indexWhere(
      (l) => l.id == id && l.type == LayerType.image,
    );
    if (index < 0) return;
    setState(() => _picking = true);
    try {
      final asset =
          await (widget.pickPhoto?.call() ??
              showPhotoSelectionSheet(context, ref));
      if (!mounted || asset == null) return;
      final file = await asset.file;
      if (!mounted) return;
      if (file == null) throw StateError('Photo not available locally');
      final pages = widget.pages.map((p) => [...p]).toList();
      pages[page][index] = pages[page][index]
          .copyWith(clearImage: true)
          .copyWith(asset: asset);
      setState(() => _files['$page:$id'] = file);
      widget.onChanged(pages);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 가져오지 못했어요. 다시 선택해주세요.')),
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  List<({int page, LayerModel layer})> get _slots => [
    for (var i = 0; i < widget.pages.length; i++)
      for (final layer in widget.pages[i])
        if (layer.type == LayerType.image) (page: i, layer: layer),
  ];

  void _nextEmpty() {
    final empty = _slots.where((s) => s.layer.asset == null).toList();
    if (empty.isEmpty) return;
    final next = empty.where((s) => s.page >= _page).firstOrNull ?? empty.first;
    setState(() => _page = next.page);
    _pick(next.page, next.layer.id);
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final filled = slots.where((s) => s.layer.asset != null).length;
    final ink = SnapFitColors.textPrimaryOf(context);
    final muted = SnapFitColors.textSecondaryOf(context);
    final stageColor = SnapFitColors.isDark(context)
        ? const Color(0xFF222727)
        : const Color(0xFFF0F2F1);
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 640;
          final pageIndex = wide && _page > 0
              ? ((_page - 1) ~/ 2) * 2 + 1
              : _page;
          final indices = [
            pageIndex,
            if (wide && pageIndex > 0 && pageIndex + 1 < widget.pages.length)
              pageIndex + 1,
          ];
          final preview = LayoutBuilder(
            builder: (context, box) {
              final canvas = coverCanvasBaseSize(widget.cover);
              final scale = math.max(
                .01,
                math.min(
                  (box.maxWidth - 32) / (canvas.width * indices.length),
                  (box.maxHeight - 24) / canvas.height,
                ),
              );
              return Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final i in indices)
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .09),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TemplatePageRenderer(
                          layers: widget.pages[i],
                          width: canvas.width * scale,
                          height: canvas.height * scale,
                          designCanvasSize: canvas,
                          preserveTypography: widget.preserveTypography,
                          showCanvasChrome: true,
                          localFiles: {
                            for (final l in widget.pages[i])
                              if (_files['$i:${l.id}'] != null)
                                l.id: _files['$i:${l.id}']!,
                          },
                          onLayerTap: (id) => _pick(i, id),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
          final rail = ListView.separated(
            scrollDirection: wide ? Axis.vertical : Axis.horizontal,
            padding: const EdgeInsets.all(12),
            itemCount: widget.pages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10, height: 10),
            itemBuilder: (context, index) {
              final selected = indices.contains(index);
              return Semantics(
                selected: selected,
                button: true,
                label: index == 0 ? '표지' : '$index쪽',
                child: InkWell(
                  key: ValueKey('fill-page-$index'),
                  onTap: () => setState(() => _page = index),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 70,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF43877E)
                            : ink.withValues(alpha: .12),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 54,
                          height: 48,
                          child: FittedBox(
                            child: TemplatePageRenderer(
                              layers: widget.pages[index],
                              width: coverCanvasBaseSize(widget.cover).width,
                              height: coverCanvasBaseSize(widget.cover).height,
                              designCanvasSize: coverCanvasBaseSize(
                                widget.cover,
                              ),
                              showCanvasChrome: true,
                              preserveTypography: widget.preserveTypography,
                              localFiles: {
                                for (final l in widget.pages[index])
                                  if (_files['$index:${l.id}'] != null)
                                    l.id: _files['$index:${l.id}']!,
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          index == 0 ? '표지' : '$index',
                          style: TextStyle(fontSize: 11, color: ink),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '사진 채우기',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                    Text(
                      '$filled / ${slots.length}',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(
                            child: ColoredBox(
                              color: stageColor,
                              child: preview,
                            ),
                          ),
                          SizedBox(width: 98, child: rail),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ColoredBox(
                              color: stageColor,
                              child: preview,
                            ),
                          ),
                          SizedBox(height: 120, child: rail),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Row(
                  children: [
                    if (filled < slots.length) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _picking ? null : _nextEmpty,
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 20,
                          ),
                          label: const Text('사진 추가'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            textStyle: const TextStyle(
                              fontFamily: SnapFitFonts.body,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _picking ? null : widget.onContinue,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          elevation: 0,
                          backgroundColor: ink,
                          foregroundColor: SnapFitColors.backgroundOf(context),
                          textStyle: const TextStyle(
                            fontFamily: SnapFitFonts.body,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          filled < slots.length ? '나중에 채우기' : '표지 확인',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
