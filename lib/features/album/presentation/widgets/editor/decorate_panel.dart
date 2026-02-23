import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../domain/entities/layer.dart'; // Just in case

class DecoratePanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const DecoratePanel({super.key, this.onClose});

  @override
  ConsumerState<DecoratePanel> createState() => _DecoratePanelState();
}

class _DecoratePanelState extends ConsumerState<DecoratePanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 다크 테마 배경색 (디자인 시안 기준)
    const bgColor = Color(0xFF0F1113);
    const surfaceColor = Color(0xFF1E2124);

    return Container(
      height: 520.h, // 충분한 높이 확보
      decoration: BoxDecoration(
        color: SnapFitColors.backgroundOf(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Column(
        children: [
          // Handle
          SizedBox(height: 12.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: SnapFitColors.textPrimaryOf(context).withOpacity(0.2),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: SnapFitColors.textPrimaryOf(context), size: 24.sp),
                  onPressed: () => widget.onClose?.call(),
                ),
                Text(
                  "꾸미기",
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
                // 적용 버튼
                ElevatedButton(
                  onPressed: () => widget.onClose?.call(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF162A2E), // 디자인 기준 어두운 청록색
                    foregroundColor: SnapFitColors.accent,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    "적용",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // TabBar
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: SnapFitColors.textPrimaryOf(context),
              unselectedLabelColor: SnapFitColors.textPrimaryOf(context).withOpacity(0.5),
              indicatorColor: SnapFitColors.accent,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelPadding: EdgeInsets.symmetric(horizontal: 20.w),
              labelStyle: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: "추천스티커"),
                Tab(text: "배경 색상"),
                Tab(text: "프레임스타일"),
              ],
            ),
          ),
          
          const Divider(color: Colors.black12, height: 1),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStickerTab(SnapFitColors.surfaceOf(context)),
                _buildColorTab(SnapFitColors.surfaceOf(context)),
                _buildFrameTab(SnapFitColors.surfaceOf(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerTab(Color surfaceColor) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("인기 스티커", onSeeAll: () {}),
          SizedBox(height: 16.h),
          _buildStickerGrid(surfaceColor),
          SizedBox(height: 32.h),
          _buildSectionHeader("인기 프레임", onSeeAll: () {}),
          SizedBox(height: 16.h),
          _buildFrameList(surfaceColor),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              "전체보기",
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF00C2E0).withOpacity(0.8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStickerGrid(Color surfaceColor) {
    // 실제 시안 아이콘 (일단 이모지로 임시 대체하되 시안과 유사하게 배치)
    final stickers = ["❤️", "⭐", "☀️", "🐾", "🔥", "✨", "😊", "🤝", "🌸", "🐶", "🎨", "🌈"];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final isSelected = index == 0; // 데모용 첫번째 선택
        return GestureDetector(
          onTap: () {
             final vm = ref.read(albumEditorViewModelProvider.notifier);
             final state = ref.read(albumEditorViewModelProvider).value;
             final canvasSize = state?.coverCanvasSize ?? const Size(300, 400);
             vm.addTextLayer(
               stickers[index], 
               style: TextStyle(fontSize: 60.sp), 
               mode: TextStyleType.none,
               canvasSize: canvasSize
             );
          },
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12.r),
              border: isSelected 
                ? Border.all(color: SnapFitColors.accent, width: 2)
                : null,
            ),
            child: Stack(
              children: [
                Center(child: Text(stickers[index], style: TextStyle(fontSize: 28.sp))),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.check_circle, color: SnapFitColors.accent, size: 16.sp),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrameList(Color surfaceColor) {
    final frames = [
      {"label": "폴라로이드", "icon": Icons.crop_portrait_outlined},
      {"label": "라운드 프레임", "icon": Icons.crop_free_outlined},
    ];

    return SizedBox(
      height: 100.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: frames.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final f = frames[index];
          final isSelected = index == 1; // 데모용
          return GestureDetector(
            onTap: () {},
            child: Container(
              width: 140.w,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12.r),
                border: isSelected 
                  ? Border.all(color: SnapFitColors.accent, width: 1.5)
                  : Border.all(color: SnapFitColors.overlayLightOf(context)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(f["icon"] as IconData, color: SnapFitColors.textPrimaryOf(context), size: 32.sp),
                  SizedBox(height: 8.h),
                  Text(
                    f["label"] as String,
                    style: TextStyle(
                      color: isSelected ? SnapFitColors.accent : SnapFitColors.textSecondaryOf(context),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorTab(Color surfaceColor) {
    final colors = [
      Colors.white, const Color(0xFFEFEFEF), const Color(0xFFD9D9D9), const Color(0xFFB3B3B3),
      const Color(0xFF808080), Colors.black, const Color(0xFFFFEBEE), const Color(0xFFF3E5F5),
      const Color(0xFFE3F2FD), const Color(0xFFE8F5E9), const Color(0xFFFFFDE7), const Color(0xFFFFF3E0),
    ];

    return GridView.builder(
      padding: EdgeInsets.all(20.w),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            ref.read(albumEditorViewModelProvider.notifier).updatePageBackgroundColor(colors[index].value);
          },
          child: Container(
            decoration: BoxDecoration(
              color: colors[index],
              shape: BoxShape.circle,
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrameTab(Color surfaceColor) {
    // 프레임 상세 설정 탭 (기존 Grid 재활용)
    return Center(
      child: Text(
        "프레임 스타일 준비 중",
        style: TextStyle(color: SnapFitColors.textSecondaryOf(context), fontSize: 14.sp),
      ),
    );
  }
}
