import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/presentation/views/subscription_management_screen.dart';
import '../../domain/entities/premium_template.dart';
import '../../data/api/template_provider.dart';
import '../../../album/presentation/widgets/home/home_album_actions.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../widgets/template_page_renderer.dart';
import 'template_full_screen_view.dart';
import '../../../album/presentation/views/album_create_flow_screen.dart';

class TemplateDetailScreen extends ConsumerStatefulWidget {
  final PremiumTemplate template;

  const TemplateDetailScreen({super.key, required this.template});

  @override
  ConsumerState<TemplateDetailScreen> createState() =>
      _TemplateDetailScreenState();
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

  String _normalizeTitle(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
  }

  Future<PremiumTemplate?> _findRemoteMatchByTitle() async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      final remoteList = await repository.getTemplates();
      if (remoteList.isEmpty) return null;

      final key = _normalizeTitle(_template.title);
      for (final t in remoteList) {
        if (_normalizeTitle(t.title) == key) {
          // 로컬 템플릿의 풍부한 미리보기/JSON이 있으면 우선 사용
          return t.copyWith(
            previewImages: _template.previewImages.isNotEmpty
                ? _template.previewImages
                : t.previewImages,
            templateJson:
                (_template.templateJson != null &&
                    _template.templateJson!.isNotEmpty)
                ? _template.templateJson
                : t.templateJson,
          );
        }
      }
    } catch (_) {
      // ignore and fallback
    }
    return null;
  }

  void _parseTemplateJson() {
    if (_template.templateJson == null || _template.templateJson!.isEmpty) {
      // 이미 파싱된 템플릿이 있으면 유지 (리프레시 시 빈 JSON으로 덮이지 않게)
      if (_parsedPages.isEmpty) {
        _parsedPages = [];
      }
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
      AppLogger.warn('Failed to parse templateJson: $e');
      if (_parsedPages.isEmpty) {
        _parsedPages = [];
      }
    }
  }

  Future<void> _refreshTemplate() async {
    try {
      PremiumTemplate? updated;
      if (_template.id < 0) {
        updated = await _findRemoteMatchByTitle();
      } else {
        updated = await ref
            .read(templateRepositoryProvider)
            .getTemplate(_template.id);
      }

      if (updated == null) return;
      final updatedTemplate = updated;
      if (mounted) {
        setState(() {
          _template = updatedTemplate;
          _parseTemplateJson(); // Re-parse on update
        });
      }
    } catch (e) {
      // Ignore initial fetch error if offline or just rely on passed data
    }
  }

  Future<void> _onLike() async {
    var target = _template;
    if (target.id < 0) {
      final matched = await _findRemoteMatchByTitle();
      if (matched != null && mounted) {
        setState(() {
          _template = matched;
          target = matched;
        });
      }
    }

    if (target.id < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 템플릿은 아직 좋아요 서버 연동 전입니다.')),
        );
      }
      return;
    }

    final oldStatus = target.isLiked;
    final oldCount = target.likeCount;

    // 1. Optimistic Update
    setState(() {
      _template = target.copyWith(
        isLiked: !oldStatus,
        likeCount: oldStatus ? oldCount - 1 : oldCount + 1,
      );
    });

    try {
      // 2. API Call
      await ref.read(templateRepositoryProvider).likeTemplate(target.id);

      // 3. Server truth 재동기화
      final refreshed = await ref
          .read(templateRepositoryProvider)
          .getTemplate(target.id);
      setState(() {
        _template = refreshed;
      });

      // Invalidate list provider so the previous screen updates
      ref.invalidate(templateListProvider);
    } catch (e) {
      // 3. Rollback on failure
      if (mounted) {
        setState(() {
          _template = target.copyWith(isLiked: oldStatus, likeCount: oldCount);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('좋아요 처리에 실패했습니다: $e')));
      }
    }
  }

  Future<void> _onUse() async {
    if (_isUsing) return;
    if (_template.isPremium) {
      final granted = await _ensureSubscriptionForPremium();
      if (!granted) return;
    }

    setState(() => _isUsing = true);
    final pages = _resolvePagesForCreateFlow();
    if (pages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('템플릿 데이터 준비에 실패했습니다.')));
        setState(() => _isUsing = false);
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumCreateFlowScreen(
          initialTemplatePages: pages,
          initialAlbumTitle: _template.title,
          initialTemplatePreviewImages: _template.previewImages,
        ),
      ),
    );
    if (mounted) {
      setState(() => _isUsing = false);
    }
  }

  Future<bool> _ensureSubscriptionForPremium() async {
    try {
      final state = await ref.read(mySubscriptionProvider.future);
      if (state.isActive) return true;
    } catch (_) {}

    if (!mounted) return false;
    final shouldProceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '프리미엄 템플릿 잠금',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '이 템플릿은 구독자 전용입니다. PG 결제로 구독 후 바로 사용하실 수 있어요.',
                  style: TextStyle(
                    color: SnapFitColors.textSecondaryOf(context),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('PG로 구독하기'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('다음에 할게요'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldProceed != true) return false;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()),
    );

    ref.invalidate(mySubscriptionProvider);
    final latest = await ref.read(mySubscriptionProvider.future);
    return latest.isActive;
  }

  Future<void> _onShareTemplate() async {
    final subtitle = _template.subTitle?.trim();
    final lines = <String>[
      'SnapFit 템플릿 공유',
      _template.title,
      if (subtitle != null && subtitle.isNotEmpty) subtitle,
      _template.coverImageUrl,
    ];
    final text = lines.join('\n');

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공유 기능을 실행할 수 없습니다.')));
    }
  }

  List<List<LayerModel>> _resolvePagesForCreateFlow() {
    if (_parsedPages.isNotEmpty) return _parsedPages;
    return _buildFallbackTemplatePages();
  }

  List<List<LayerModel>> _buildFallbackTemplatePages() {
    final preview = _template.previewImages;
    if (preview.isEmpty) return const [];
    final pageCount = _template.pageCount < 2 ? 2 : _template.pageCount;
    final pages = <List<LayerModel>>[];

    LayerModel imageLayer({
      required String id,
      required String url,
      required double x,
      required double y,
      required double w,
      required double h,
      String frame = 'photoCard',
      int z = 10,
    }) {
      return LayerModel(
        id: id,
        type: LayerType.image,
        position: Offset(x, y),
        width: w,
        height: h,
        imageBackground: frame,
        previewUrl: url,
        imageUrl: url,
        originalUrl: url,
        zIndex: z,
      );
    }

    pages.add([
      imageLayer(
        id: 'cover_main',
        url: preview.first,
        x: 56,
        y: 82,
        w: 388,
        h: 300,
        frame: 'paperClipCard',
      ),
      LayerModel(
        id: 'cover_title',
        type: LayerType.text,
        position: const Offset(84, 24),
        width: 332,
        height: 44,
        text: _template.title,
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
        ),
        zIndex: 20,
      ),
    ]);

    for (int i = 1; i < pageCount; i++) {
      final left = preview[i % preview.length];
      final right = preview[(i + 1) % preview.length];
      pages.add([
        imageLayer(
          id: 'p${i}_left',
          url: left,
          x: 52,
          y: 78,
          w: 196,
          h: 314,
          frame: 'collageTile',
        ),
        imageLayer(
          id: 'p${i}_right',
          url: right,
          x: 252,
          y: 78,
          w: 196,
          h: 314,
          frame: 'collageTile',
        ),
      ]);
    }
    return pages;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = SnapFitColors.textPrimaryOf(context);
    final secondaryColor = SnapFitColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
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
                              decoration: BoxDecoration(
                                color: SnapFitColors.surfaceOf(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: 20,
                                color: titleColor,
                              ),
                            ),
                          ),
                          Text(
                            '템플릿 상세',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: _onShareTemplate,
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: SnapFitColors.surfaceOf(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.share_outlined,
                                size: 20,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30.h),

                    _buildHeroImage(context),

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
                              color: titleColor,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          if (_template.subTitle != null)
                            Text(
                              _template.subTitle!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: secondaryColor,
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
                            Expanded(
                              child: _buildFeatureCard(
                                context,
                                Icons.photo_library_outlined,
                                '제주 전용 레이아웃',
                                '여행지 감성에 맞춘 스티커와 프레임이 포함되어 있습니다.',
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildFeatureCard(
                                context,
                                Icons.people_outline,
                                '5인 협업 최적화',
                                '가족, 친구들과 함께 각자의 페이지를 동시에 편집하세요.',
                              ),
                            ),
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
                              color: titleColor,
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
                            return _buildPageLayoutPreview(
                              context,
                              index,
                              _parsedPages[index],
                            );
                          }
                          // 2. Fallback to preview images
                          if (index < _template.previewImages.length) {
                            return _buildPagePreviewItem(
                              context,
                              _template.previewImages[index],
                            );
                          }
                          // 3. Fallback to placeholder
                          return _buildPagePreviewPlaceholder(context, index);
                        },
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: Text(
                          '표지 및 프롤로그',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 40.h),

                    // User Count Badge
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20.w),
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                        horizontal: 20.w,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? SnapFitColors.surfaceOf(context)
                            : const Color(0xFFEBF8F9),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60.w,
                            height: 30.w,
                            child: Stack(
                              children: [
                                _avatar(
                                  context,
                                  0,
                                  isDark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                                _avatar(
                                  context,
                                  18.w,
                                  isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[400]!,
                                ),
                                _avatar(
                                  context,
                                  36.w,
                                  isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[500]!,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: SnapFitColors.textSecondaryOf(context),
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
                bottom: MediaQuery.of(context).padding.bottom + 20.h,
              ),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                          _template.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _template.isLiked
                              ? Colors.red
                              : SnapFitColors.textMutedOf(context),
                          size: 28.sp,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${_template.likeCount}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: _template.isLiked
                                ? Colors.red
                                : SnapFitColors.textMutedOf(context),
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
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
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

  Widget _buildHeroImage(BuildContext context) {
    return Center(
      child: Container(
        width: 320.w,
        height: 380.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: SnapFitColors.surfaceOf(context),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
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

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
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
              color: isDark
                  ? SnapFitColors.accent.withOpacity(0.16)
                  : const Color(0xFFEBF8F9),
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
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12.sp,
              color: SnapFitColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagePreviewPlaceholder(BuildContext context, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 180.w,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Center(
        child: Container(
          width: 140.w,
          height: 200.h,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Center(
            child: Text(
              "Preview ${index + 1}",
              style: TextStyle(color: SnapFitColors.textMutedOf(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagePreviewItem(BuildContext context, String imageUrl) {
    return Container(
      width: 180.w,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageLayoutPreview(
    BuildContext context,
    int index,
    List<LayerModel> layers,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _openFullScreenView(index),
      child: Container(
        width: 180.w,
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
        ),
        child: Center(
          child: Container(
            width: 140.w,
            height: 140.w,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: SnapFitColors.backgroundOf(context),
              borderRadius: BorderRadius.circular(4.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
                  blurRadius: 4,
                ),
              ],
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

  Widget _avatar(BuildContext context, double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: SnapFitColors.backgroundOf(context),
            width: 2,
          ),
        ),
        child: Icon(Icons.person, color: Colors.white, size: 16.sp),
      ),
    );
  }
}
