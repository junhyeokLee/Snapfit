import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/premium_template.dart';
import '../../../album/domain/entities/layer.dart';
import '../widgets/template_page_renderer.dart';
import '../../data/api/template_provider.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../album/data/api/storage_service.dart';
import '../../../album/presentation/widgets/home/home_album_actions.dart';
import '../../../album/presentation/viewmodels/album_editor_view_model.dart';
import '../../../album/presentation/views/page_editor_screen.dart';
import '../../../../core/constants/cover_size.dart';

class TemplateAssemblyScreen extends ConsumerStatefulWidget {
  final PremiumTemplate template;
  final List<List<LayerModel>> parsedPages;

  const TemplateAssemblyScreen({
    super.key,
    required this.template,
    required this.parsedPages,
  });

  @override
  ConsumerState<TemplateAssemblyScreen> createState() =>
      _TemplateAssemblyScreenState();
}

class _TemplateAssemblyScreenState
    extends ConsumerState<TemplateAssemblyScreen> {
  final Map<String, File> _selections = {};
  final ImagePicker _picker = ImagePicker();
  bool _isCreating = false;
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String layerId) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selections[layerId] = File(image.path);
      });
    }
  }

  Future<void> _onFinish() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final storageService = StorageService();
      final Map<String, String> replacements = {};

      // 1. Upload selections
      for (final entry in _selections.entries) {
        final url = await storageService.uploadFile(
          entry.value,
          'temp/assembly_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        if (url != null) {
          replacements[entry.key] = url;
        }
      }

      if (widget.template.id < 0) {
        // 로컬 피처드 템플릿: 서버 생성 없이 바로 편집 세션으로 시작
        final pageLayers = widget.parsedPages
            .map((page) {
              return page
                  .map((layer) {
                    if (layer.type != LayerType.image) return layer.copyWith();
                    final selectedUrl = replacements[layer.id];
                    if (selectedUrl == null || selectedUrl.isEmpty) {
                      return layer.copyWith();
                    }
                    return layer.copyWith(
                      previewUrl: selectedUrl,
                      imageUrl: selectedUrl,
                      originalUrl: selectedUrl,
                    );
                  })
                  .toList(growable: false);
            })
            .toList(growable: false);

        final portraitCover = coverSizes.firstWhere(
          (s) => s.name == '세로형',
          orElse: () => coverSizes.first,
        );
        ref
            .read(albumEditorViewModelProvider.notifier)
            .startLocalTemplateAlbum(
              albumTitle: widget.template.title,
              pages: pageLayers,
              initialCover: portraitCover,
            );

        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PageEditorScreen(initialPageIndex: 0),
          ),
        );
      } else {
        // 2. Call backend with replacements
        final album = await ref
            .read(templateRepositoryProvider)
            .createAlbumFromTemplate(
              widget.template.id,
              replacements: replacements,
            );

        if (!mounted) return;

        // 3. Open Album Editor
        await HomeAlbumActions.openAlbum(context, ref, album);

        // Close assembly screen
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('앨범 생성 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.surfaceLight,
      appBar: AppBar(
        title: const Text(
          '나만의 사진 채우기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: SnapFitColors.pureWhite,
        foregroundColor: SnapFitColors.deepCharcoal,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _onFinish,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '완료',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: SnapFitColors.accent,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Text(
              '템플릿의 빈 칸(슬롯)을 눌러 사진을 채워보세요.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return PageView.builder(
                  controller: _pageController,
                  itemCount: widget.parsedPages.length,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemBuilder: (context, idx) {
                    final layers = widget.parsedPages[idx];
                    final ratio = _pageAspect(layers);
                    final maxW = (constraints.maxWidth - 80.w).clamp(220.0, 620.0);
                    final maxH = (constraints.maxHeight - 40.h).clamp(220.0, 720.0);
                    var renderW = maxW;
                    var renderH = renderW / ratio;
                    if (renderH > maxH) {
                      renderH = maxH;
                      renderW = renderH * ratio;
                    }

                    return Center(
                      child: SizedBox(
                        width: renderW,
                        height: renderH,
                        child: TemplatePageRenderer(
                          layers: layers,
                          width: renderW,
                          height: renderH,
                          localFiles: _selections,
                          onLayerTap: (layerId) => _pickImage(layerId),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Page Indicator and Footer
          Container(
            padding: EdgeInsets.all(30.h),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentIndex + 1} / ${widget.parsedPages.length} 페이지',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                ElevatedButton(
                  onPressed: _isCreating ? null : _onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SnapFitColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text(
                    '앨범 생성하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _pageAspect(List<LayerModel> layers) {
    if (layers.isEmpty) return 3 / 4;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final l in layers) {
      minX = minX > l.position.dx ? l.position.dx : minX;
      minY = minY > l.position.dy ? l.position.dy : minY;
      maxX = maxX < l.position.dx + l.width ? l.position.dx + l.width : maxX;
      maxY = maxY < l.position.dy + l.height ? l.position.dy + l.height : maxY;
    }
    final w = (maxX - minX).clamp(1.0, 10000.0);
    final h = (maxY - minY).clamp(1.0, 10000.0);
    return w / h;
  }
}
