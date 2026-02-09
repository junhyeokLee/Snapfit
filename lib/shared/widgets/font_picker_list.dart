import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/snapfit_colors.dart';
import 'no_glow.dart';


/// 폰트 리스트 (옵션 영역)
class FontPickerList extends StatefulWidget {
  final List<String> families;
  final String current;
  final ValueChanged<String> onPick;
  final ScrollController? controller;
  const FontPickerList({
    super.key,
    required this.families,
    required this.current,
    required this.onPick,
    this.controller,
  });

  @override
  State<FontPickerList> createState() => FontPickerListState();
}

class FontPickerListState extends State<FontPickerList> {
  late List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = List<GlobalKey>.generate(widget.families.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant FontPickerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.families.length != _itemKeys.length) {
      _itemKeys = List<GlobalKey>.generate(widget.families.length, (_) => GlobalKey());
    }
  }

  // No dispose() needed

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60.h,
      child: ScrollConfiguration(
        behavior: const NoGlow(),
        child: ListView.separated(
          controller: widget.controller,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          physics: const BouncingScrollPhysics(),
          itemCount: widget.families.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (itemContext, i) {
            final fam = widget.families[i];
            final sel = fam == widget.current;
            return Container(
              key: _itemKeys[i],
              child: GestureDetector(
                onTap: () {
                  widget.onPick(fam);
                  // 탭한 아이템을 뷰포트 중앙으로 스크롤 (해상도 무관)
                  if (widget.controller == null) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final key = _itemKeys[i];
                    final ctx = key.currentContext;
                    if (ctx == null) return;
                    final box = ctx.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final itemPos = box.localToGlobal(Offset.zero);
                    final itemWidth = box.size.width;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final target = widget.controller!.offset + (itemPos.dx + itemWidth / 2) - (screenWidth / 2);
                    final minOffset = widget.controller!.position.minScrollExtent;
                    final maxOffset = widget.controller!.position.maxScrollExtent;
                    final clamped = target.clamp(minOffset, maxOffset);
                    widget.controller!.animateTo(
                      clamped,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  transform: sel ? Matrix4.translationValues(0, -6.h, 0) : Matrix4.identity(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: sel
                        ? SnapFitColors.surfaceOf(context)
                        : SnapFitColors.overlayLightOf(context),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: sel
                          ? SnapFitColors.textPrimaryOf(context)
                          : SnapFitColors.overlayStrongOf(context),
                      width: sel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    fam,
                    style: TextStyle(
                      color: sel
                          ? SnapFitColors.textPrimaryOf(context)
                          : SnapFitColors.textSecondaryOf(context),
                      fontSize: 12.sp,
                      fontFamily: fam,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}