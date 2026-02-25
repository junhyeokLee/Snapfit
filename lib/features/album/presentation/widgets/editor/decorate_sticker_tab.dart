import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../domain/entities/layer.dart'; // Correct relative path

class DecorateStickerTab extends ConsumerWidget {
  final Color surfaceColor;

  const DecorateStickerTab({super.key, required this.surfaceColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, '인기 스티커', onSeeAll: () {}),
          SizedBox(height: 16.h),
          _buildStickerGrid(context, ref),
          SizedBox(height: 32.h),
          _buildSectionHeader(context, '인기 프레임', onSeeAll: () {}),
          SizedBox(height: 16.h),
          _buildFrameList(context, ref),
        ],
      ),
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
            color: SnapFitColors.textPrimaryOf(context),
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

  Widget _buildStickerGrid(BuildContext context, WidgetRef ref) {
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
        final isSelected = index == 0;
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

  Widget _buildFrameList(BuildContext context, WidgetRef ref) {
    final frames = [
      {'label': '폴라로이드', 'icon': Icons.crop_portrait_outlined},
      {'label': '라운드 프레임', 'icon': Icons.crop_free_outlined},
    ];

    return SizedBox(
      height: 100.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: frames.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final f = frames[index];
          final isSelected = index == 1;
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
                  Icon(f['icon'] as IconData, color: SnapFitColors.textPrimaryOf(context), size: 32.sp),
                  SizedBox(height: 8.h),
                  Text(
                    f['label'] as String,
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
}
