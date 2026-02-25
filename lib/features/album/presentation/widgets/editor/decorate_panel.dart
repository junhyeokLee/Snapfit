import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../domain/entities/layer.dart'; // Just in case

import './decorate_sticker_tab.dart';
import './decorate_color_tab.dart';
import './decorate_frame_tab.dart';

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
    final surfaceColor = SnapFitColors.surfaceOf(context);

    return Container(
      height: 520.h,
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
              color: SnapFitColors.textPrimaryOf(context).withValues(alpha: 0.2),
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
                    backgroundColor: const Color(0xFF162A2E),
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
              unselectedLabelColor: SnapFitColors.textPrimaryOf(context).withValues(alpha: 0.5),
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
                DecorateStickerTab(surfaceColor: surfaceColor),
                DecorateColorTab(surfaceColor: surfaceColor),
                DecorateFrameTab(surfaceColor: surfaceColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
