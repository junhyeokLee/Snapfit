import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../domain/entities/premium_template.dart';
import '../../data/api/template_provider.dart';
import '../../../album/presentation/widgets/home/home_album_actions.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../widgets/template_page_renderer.dart';
import 'template_full_screen_view.dart';
import 'template_assembly_screen.dart';

class TemplateDetailScreen extends ConsumerStatefulWidget {
  final PremiumTemplate template;

  const TemplateDetailScreen({
    super.key,
    required this.template,
  });

  @override
  ConsumerState<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen> {
  late PremiumTemplate _template;
  bool _isUsing = false;
  
  // Parsed template data: List of pages, each page is a list of layers
  List<List<LayerModel>> _parsedPages = [];

  @override
  void initState() {
    super.initState();
    _template = widget.template;
    _parseTemplateJson();
    _refreshTemplate();
  }

  void _parseTemplateJson() {
    if (_template.templateJson == null || _template.templateJson!.isEmpty) {
      _parsedPages = [];
      return;
    }

    try {
      final Map<String, dynamic> data = jsonDecode(_template.templateJson!);
      final List<dynamic>? pagesList = data['pages'] as List<dynamic>?;
      
      if (pagesList != null) {
        // Assume preview canvas size (approx ratio)
        // 500x500 for parsing normalization
        const canvasSize = Size(500, 500); 
        
        _parsedPages = pagesList.map((p) {
          final map = p as Map<String, dynamic>;
          final layerList = (map['layers'] as List<dynamic>?) ?? [];
          return layerList.map((l) {
            return LayerExportMapper.fromJson(
              l as Map<String, dynamic>,
              canvasSize: canvasSize,
            );
          }).toList();
        }).toList();
        
        // Sort by pageNumber if needed, but array order usually matches
      }
    } catch (e) {
      debugPrint('Failed to parse templateJson: $e');
      _parsedPages = [];
    }
  }

  Future<void> _refreshTemplate() async {
    try {
      final updated = await ref.read(templateRepositoryProvider).getTemplate(_template.id);
      if (mounted) {
        setState(() {
          _template = updated;
          _parseTemplateJson(); // Re-parse on update
        });
      }
    } catch (e) {
      // Ignore initial fetch error if offline or just rely on passed data
    }
  }

  Future<void> _onLike() async {
    final oldStatus = _template.isLiked;
    final oldCount = _template.likeCount;

    // 1. Optimistic Update
    setState(() {
      _template = _template.copyWith(
        isLiked: !oldStatus,
        likeCount: oldStatus ? oldCount - 1 : oldCount + 1,
      );
    });

    try {
      // 2. API Call
      await ref.read(templateRepositoryProvider).likeTemplate(_template.id);
      
      // Invalidate list provider so the previous screen updates
      ref.invalidate(templateListProvider);
    } catch (e) {
      // 3. Rollback on failure
      if (mounted) {
        setState(() {
          _template = _template.copyWith(
            isLiked: oldStatus,
            likeCount: oldCount,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('좋아요 처리에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _onUse() async {
    if (_parsedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('템플릿 데이터를 불러오는데 실패했습니다.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateAssemblyScreen(
          template: _template,
          parsedPages: _parsedPages,
        ),
      ),
    );
  }

  void _openFullScreenView(int initialIndex) {
    if (_parsedPages.isEmpty && _template.previewImages.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateFullScreenView(
          parsedPages: _parsedPages,
          previewImages: _template.previewImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 60.h),
                    // Header
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back_ios_new, size: 20),
                            ),
                          ),
                          Text(
                            '템플릿 상세',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.share_outlined, size: 20),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30.h),
                    
                    _buildHeroImage(),
                    
                    SizedBox(height: 40.h),
                    
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        children: [
                          Text(
                            '이 템플릿으로 시작하기',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          if (_template.subTitle != null)
                            Text(
                              _template.subTitle!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: const Color(0xFF666666),
                                height: 1.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 40.h),
                    
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                             Expanded(child: _buildFeatureCard(Icons.photo_library_outlined, '제주 전용 레이아웃', '여행지 감성에 맞춘 스티커와 프레임이 포함되어 있습니다.')),
                             SizedBox(width: 16.w),
                             Expanded(child: _buildFeatureCard(Icons.people_outline, '5인 협업 최적화', '가족, 친구들과 함께 각자의 페이지를 동시에 편집하세요.')),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 50.h),
                    
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '페이지 미리보기',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '총 ${_template.pageCount}페이지',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: SnapFitColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      height: 240.h,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        scrollDirection: Axis.horizontal,
                        itemCount: _template.pageCount,
                        separatorBuilder: (_, __) => SizedBox(width: 16.w),
                        itemBuilder: (context, index) {
                          // 1. Try to render parsed layout
                          if (index < _parsedPages.length) {
                             return _buildPageLayoutPreview(index, _parsedPages[index]);
                          }
                          // 2. Fallback to preview images
                          if (index < _template.previewImages.length) {
                             return _buildPagePreviewItem(_template.previewImages[index]);
                          }
                          // 3. Fallback to placeholder
                          return _buildPagePreviewPlaceholder(index);
                        },
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: Text(
                          '표지 및 프롤로그',
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 40.h),
                    
                    // User Count Badge
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20.w),
                      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF8F9),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60.w,
                            height: 30.w,
                            child: Stack(
                              children: [
                                _avatar(0, Colors.grey[300]!),
                                _avatar(18.w, Colors.grey[400]!),
                                _avatar(36.w, Colors.grey[500]!),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: const Color(0xFF555555),
                                ),
                                children: [
                                  const TextSpan(text: '현재 '),
                                  TextSpan(
                                    text: '${_template.userCount}명',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: SnapFitColors.accent,
                                    ),
                                  ),
                                  const TextSpan(text: '이 이 템플릿으로 제작 중입니다.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 120.h),
                  ],
                ),
              ),
            ],
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20.w, 
                right: 20.w, 
                top: 20.h, 
                bottom: MediaQuery.of(context).padding.bottom + 20.h
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _onLike,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _template.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _template.isLiked ? Colors.red : Colors.grey,
                          size: 28.sp,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${_template.likeCount}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: _template.isLiked ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUsing ? null : _onUse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SnapFitColors.accent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isUsing 
                        ? SizedBox(
                            width: 24.w, 
                            height: 24.w, 
                            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '이 템플릿 사용하기',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return Center(
      child: Container(
        width: 320.w,
        height: 380.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: const Color(0xFFE5DCD0),
          image: DecorationImage(
            image: NetworkImage(_template.coverImageUrl),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
           children: [
             if (_template.isBest || _template.isPremium)
              Positioned(
                top: 24.h,
                left: 24.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C7D8),
                    borderRadius: BorderRadius.circular(100.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
             Positioned(
               bottom: 24.h,
               left: 24.w,
               right: 24.w,
               child: Text(
                _template.title.replaceAll(' ', ' '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
               ),
             ),
           ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
             padding: EdgeInsets.all(10.w),
             decoration: BoxDecoration(
               color: const Color(0xFFEBF8F9),
               shape: BoxShape.circle,
             ),
             child: Icon(icon, color: SnapFitColors.accent, size: 24.sp),
           ),
           SizedBox(height: 16.h),
           Text(
             title,
             style: TextStyle(
               fontSize: 15.sp,
               fontWeight: FontWeight.bold,
               color: const Color(0xFF1A1A1A),
             ),
           ),
           SizedBox(height: 8.h),
           Text(
             desc,
             style: TextStyle(
               fontSize: 12.sp,
               color: const Color(0xFF888888),
               height: 1.4,
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildPagePreviewPlaceholder(int index) {
    return Container(
      width: 180.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Center(
        child: Container(
          width: 140.w,
          height: 200.h,
          decoration: BoxDecoration(
//            border: Border.all(color: SnapFitColors.accent.withOpacity(0.3), width: 1.5),
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Center(
              child: Text("Preview ${index + 1}", style: TextStyle(color: Colors.grey))
          ),
        ),
      ),
    );
  }

  Widget _buildPagePreviewItem(String imageUrl) {
    return Container(
      width: 180.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Center(
        child: Container(
          width: 140.w,
          height: 200.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            )
          ),
        ),
      ),
    );
  }
  
  Widget _buildPageLayoutPreview(int index, List<LayerModel> layers) {
    return GestureDetector(
      onTap: () => _openFullScreenView(index),
      child: Container(
        width: 180.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Center(
          child: Container(
            width: 140.w,
            height: 140.w,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                )
              ]
            ),
            child: TemplatePageRenderer(
              layers: layers,
              width: 140.w,
              height: 140.w,
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(Icons.person, color: Colors.white, size: 16.sp),
      ),
    );
  }
}

