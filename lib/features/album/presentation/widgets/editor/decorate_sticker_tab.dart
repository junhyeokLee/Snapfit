import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/snapfit_colors.dart';

class DecorateStickerTab extends ConsumerStatefulWidget {
  final Color surfaceColor;
  final void Function(String sticker)? onStickerTap;

  const DecorateStickerTab({
    super.key,
    required this.surfaceColor,
    this.onStickerTap,
  });

  @override
  ConsumerState<DecorateStickerTab> createState() => _DecorateStickerTabState();
}

class _DecorateStickerTabState extends ConsumerState<DecorateStickerTab> {
  int? _selectedStickerIndex;

  static const List<String> _stickersPreview = [
    "❤️","⭐","☀️","🐾","🔥","✨","😊","🤝","🌸","🐶","🎨","🌈",
    "🧡","💛","💚","💙","💜","🖤","🤍","🩷",
  ];

  static const List<String> _stickersAll = [
    // hearts / sparkle
    "❤️","🧡","💛","💚","💙","💜","🖤","🤍","🩷","💖","💘","💝","💞","💟",
    "✨","⭐","🌟","💫","🔥","🌈","☀️","🌤️","🌙","⚡",
    // faces / hands
    "😊","😍","🥰","😎","🤩","🥳","😭","😆","🤝","👏","🙌","👍","🫶","🙏",
    // pets / nature
    "🐶","🐱","🐰","🐻","🐼","🦊","🐾","🌸","🌷","🌼","🍀","🌿","🌵","🍃",
    // party / deco
    "🎈","🎉","🎊","🎁","🎀","🎨","🖍️","📸","🧸","🍰","🧁","🍭","🍓","🍒",
    // travel / daily
    "✈️","🚗","🏠","🛍️","☕","🍿","🎧","📚","🕶️","⌚","🧩","🧡",
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, '인기 스티커', onSeeAll: _openAllStickersSheet),
          SizedBox(height: 16.h),
          _buildStickerGrid(context),
        ],
      ),
    );
  }

  Future<void> _openAllStickersSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: BoxDecoration(
            color: SnapFitColors.surfaceOf(context),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: SnapFitColors.textPrimaryOf(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  '스티커 전체보기',
                  style: TextStyle(
                    color: SnapFitColors.textPrimaryOf(context),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12.h),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _stickersAll.length,
                    itemBuilder: (context, index) {
                      final sticker = _stickersAll[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop(); // 전체보기 닫기
                          widget.onStickerTap?.call(sticker); // 선택 → (상위에서) 시트 닫힘
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.surfaceColor,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: SnapFitColors.overlayLightOf(context),
                            ),
                          ),
                          child: Center(
                            child: Text(sticker, style: TextStyle(fontSize: 28.sp)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.isDark(context)
                ? Colors.white
                : Colors.black87,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              '전체보기',
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF00C2E0).withValues(alpha: 0.8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStickerGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _stickersPreview.length,
      itemBuilder: (context, index) {
        final isSelected = _selectedStickerIndex == index;
        return GestureDetector(
          onTap: () {
             setState(() {
               _selectedStickerIndex = index;
             });
             widget.onStickerTap?.call(_stickersPreview[index]);
          },
          child: Container(
            decoration: BoxDecoration(
              color: widget.surfaceColor,
              borderRadius: BorderRadius.circular(12.r),
              border: isSelected 
                ? Border.all(color: SnapFitColors.accent, width: 2)
                : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    _stickersPreview[index],
                    style: TextStyle(fontSize: 28.sp),
                  ),
                ),
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

}

/// 레이아웃(찢김 스크랩) 전용 탭
class DecorateLayoutTab extends StatelessWidget {
  final Color surfaceColor;
  final void Function(String layoutKey)? onLayoutTap;

  const DecorateLayoutTab({
    super.key,
    required this.surfaceColor,
    this.onLayoutTap,
  });

  static const List<String> _layoutKeys = ['scrap1', 'scrap2', 'scrap3'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: GridView.builder(
        itemCount: _layoutKeys.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final key = _layoutKeys[index];
          return GestureDetector(
            onTap: () => onLayoutTap?.call(key),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Image.asset(
                          'assets/sticker/$key.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      key,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
