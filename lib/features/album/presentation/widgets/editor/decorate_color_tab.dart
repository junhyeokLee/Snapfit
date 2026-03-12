import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../viewmodels/album_editor_view_model.dart';

class DecorateColorTab extends ConsumerStatefulWidget {
  final Color surfaceColor;
  final void Function(int colorValue)? onColorTap;

  const DecorateColorTab({
    super.key,
    required this.surfaceColor,
    this.onColorTap,
  });

  @override
  ConsumerState<DecorateColorTab> createState() => _DecorateColorTabState();
}

class _DecorateColorTabState extends ConsumerState<DecorateColorTab> {
  int? _selectedColorIndex;

  /// 전체 색상(스크롤) — 파스텔 + 진한 원색/딥톤 포함
  static const List<Color> _colorsAll = [
    // neutrals
    Colors.white,
    Color(0xFFF7F7F7),
    Color(0xFFEFEFEF),
    Color(0xFFE3E3E3),
    Color(0xFFD9D9D9),
    Color(0xFFCCCCCC),
    Color(0xFFB3B3B3),
    Color(0xFF999999),
    Color(0xFF808080),
    Color(0xFF666666),
    Color(0xFF4D4D4D),
    Color(0xFF2B2B2B),
    Colors.black,

    // pastel-ish
    Color(0xFFFFEBEE),
    Color(0xFFFFCDD2),
    Color(0xFFFCE4EC),
    Color(0xFFF8BBD0),
    Color(0xFFF3E5F5),
    Color(0xFFE1BEE7),
    Color(0xFFEDE7F6),
    Color(0xFFD1C4E9),
    Color(0xFFE3F2FD),
    Color(0xFFBBDEFB),
    Color(0xFFE0F7FA),
    Color(0xFFB2EBF2),
    Color(0xFFE8F5E9),
    Color(0xFFC8E6C9),
    Color(0xFFF1F8E9),
    Color(0xFFDCEDC8),
    Color(0xFFFFFDE7),
    Color(0xFFFFF9C4),
    Color(0xFFFFF8E1),
    Color(0xFFFFECB3),
    Color(0xFFFFF3E0),
    Color(0xFFFFE0B2),
    Color(0xFFFFCCBC),
    Color(0xFFFFAB91),

    // saturated / deep tones (요청: 더 진한 색)
    Colors.red,
    Colors.redAccent,
    Colors.pink,
    Colors.pinkAccent,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.blueAccent,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.greenAccent,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,

    // custom deep palette
    Color(0xFF0F172A), // slate-900
    Color(0xFF1E293B), // slate-800
    Color(0xFF111827), // gray-900
    Color(0xFF7F1D1D), // deep red
    Color(0xFF991B1B),
    Color(0xFF9A3412), // deep orange
    Color(0xFFB45309),
    Color(0xFF166534), // deep green
    Color(0xFF065F46), // deep teal
    Color(0xFF1D4ED8), // deep blue
    Color(0xFF1E40AF), // indigo deep
    Color(0xFF6D28D9), // deep violet
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      // +1: 맨 앞에 "배경 없음" 옵션 추가
      itemCount: _colorsAll.length + 1,
      itemBuilder: (context, index) {
        // 0번 인덱스: 배경 없음
        if (index == 0) {
          final bool isSelected = _selectedColorIndex == null;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedColorIndex = null;
              });

              // 콜백이 있으면 상위(DecoratePanel 등)에 위임
              // -1: "배경 없음"을 의미하는 sentinal 값
              if (widget.onColorTap != null) {
                widget.onColorTap!.call(-1);
                return;
              }

              // 직접 사용되는 경우에는 여기서 바로 배경 제거
              ref
                  .read(albumEditorViewModelProvider.notifier)
                  .clearPageBackgroundColor();
            },
            child: Container(
              decoration: BoxDecoration(
                color: widget.surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? SnapFitColors.accent
                      : SnapFitColors.overlayLightOf(context),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Icon(
                Icons.block, // 빨간색 금지 아이콘
                size: 16.sp,
                color: Colors.redAccent,
              ),
            ),
          );
        }

        // 나머지 인덱스: 실제 색상
        final color = _colorsAll[index - 1];
        final isSelected = _selectedColorIndex == index - 1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColorIndex = index - 1;
            });
            if (widget.onColorTap != null) {
              widget.onColorTap!.call(color.value);
              return;
            }
            ref.read(albumEditorViewModelProvider.notifier).updatePageBackgroundColor(color.value);
          },
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? SnapFitColors.accent : SnapFitColors.overlayLightOf(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 14.sp,
                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  )
                : null,
          ),
        );
      },
    );
  }
}
