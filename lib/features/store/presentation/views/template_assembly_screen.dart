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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '나만의 사진 채우기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.parsedPages.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, idx) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.all(40.w),
                    child: TemplatePageRenderer(
                      layers: widget.parsedPages[idx],
                      width: 1.sw - 80.w,
                      height:
                          1.sw -
                          80.w, // Assume square for simplicity or keep ratio
                      localFiles: _selections,
                      onLayerTap: (layerId) => _pickImage(layerId),
                    ),
                  ),
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
}
