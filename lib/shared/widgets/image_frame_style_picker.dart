import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 이미지 프레임 스타일 정의
class ImageFrameStyle {
  final String key;
  final String label;
  final IconData? icon;

  const ImageFrameStyle({
    required this.key,
    required this.label,
    this.icon,
  });
}

/// 사용 가능한 이미지 프레임 스타일 목록
const List<ImageFrameStyle> imageFrameStyles = [
  ImageFrameStyle(key: '', label: '기본', icon: Icons.crop_square),
  ImageFrameStyle(key: 'round', label: '라운드', icon: Icons.rounded_corner),
  ImageFrameStyle(key: 'polaroid', label: '폴라로이드', icon: Icons.photo_size_select_actual),
  ImageFrameStyle(key: 'polaroidClassic', label: '폴라로이드 클래식', icon: Icons.photo_camera),
  ImageFrameStyle(key: 'polaroidWide', label: '폴라로이드 와이드', icon: Icons.photo_library),
  ImageFrameStyle(key: 'sticker', label: '스티커', icon: Icons.label),
  ImageFrameStyle(key: 'vintage', label: '빈티지', icon: Icons.auto_fix_high),
  ImageFrameStyle(key: 'film', label: '필름', icon: Icons.movie_filter),
  ImageFrameStyle(key: 'softGlow', label: '소프트', icon: Icons.blur_on),
  ImageFrameStyle(key: 'sketch', label: '스케치', icon: Icons.draw),
];

/// 이미지 프레임 스타일 선택 바텀시트
class ImageFrameStylePicker extends StatelessWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const ImageFrameStylePicker({
    super.key,
    required this.selectedKey,
    required this.onSelect,
  });

  static Future<String?> show(
    BuildContext context, {
    required String? currentKey,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImageFrameStylePicker(
        selectedKey: currentKey,
        onSelect: (key) => Navigator.pop(ctx, key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF9893a9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20.r,
            offset: Offset(0, -4.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            // 드래그 핸들
            Container(
              width: 48.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 20.h),
            // 제목
            Text(
              '사진 스타일',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16.h),
            // 프레임 스타일 그리드
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 24.h),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 4;
                  const mainSpacing = 12.0;
                  const crossSpacing = 12.0;
                  final itemWidth =
                      (constraints.maxWidth - (crossSpacing * (crossAxisCount - 1))) /
                          crossAxisCount;

                  return Wrap(
                    spacing: crossSpacing,
                    runSpacing: mainSpacing,
                    children: imageFrameStyles.map((style) {
                      final isSelected =
                          (selectedKey ?? '') == style.key;
                      return SizedBox(
                        width: itemWidth,
                        child: _FrameStyleItem(
                          style: style,
                          isSelected: isSelected,
                          onTap: () => onSelect(style.key),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameStyleItem extends StatelessWidget {
  final ImageFrameStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  const _FrameStyleItem({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12.r,
                    offset: Offset(0, 4.h),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 미니 프레임 미리보기
            SizedBox(
              width: 64.w,
              height: 64.w,
              child: _buildFramePreview(style.key),
            ),
            SizedBox(height: 6.h),
            Text(
              style.label,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.white,
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFramePreview(String key) {
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7d7a97),
            const Color(0xFF9893a9),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo,
          color: Colors.white.withOpacity(0.6),
          size: 24,
        ),
      ),
    );

    Widget content;
    switch (key) {
      case 'round':
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: placeholder,
        );
        break;
      case 'polaroid':
        content = _previewPolaroid(placeholder);
        break;
      case 'polaroidClassic':
        content = _previewPolaroidClassic(placeholder);
        break;
      case 'polaroidWide':
        content = _previewPolaroidWide(placeholder);
        break;
      case 'sticker':
        content = Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: placeholder,
          ),
        );
        break;
      case 'vintage':
        content = Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF4E8D3),
            borderRadius: BorderRadius.circular(4.r),
            border: Border.all(color: Colors.brown.withOpacity(0.5), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: placeholder,
          ),
        );
        break;
      case 'film':
        content = Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.w),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: placeholder,
          ),
        );
        break;
      case 'softGlow':
        content = Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: placeholder,
          ),
        );
        break;
      case 'sketch':
        content = Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(4.r),
            border: Border.all(color: Colors.black87, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: placeholder,
          ),
        );
        break;
      default:
        content = placeholder;
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 56,
        height: 56,
        child: content,
      ),
    );
  }

  Widget _previewPolaroid(Widget child) {
    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 4.w, 4.w, 12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.4), width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: child,
      ),
    );
  }

  Widget _previewPolaroidClassic(Widget child) {
    return Container(
      padding: EdgeInsets.fromLTRB(6.w, 6.w, 6.w, 18.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF5),
        borderRadius: BorderRadius.circular(6.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8E4D8), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.r),
        child: child,
      ),
    );
  }

  Widget _previewPolaroidWide(Widget child) {
    return Container(
      padding: EdgeInsets.fromLTRB(2.w, 6.w, 2.w, 14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.35), width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.r),
        child: child,
      ),
    );
  }
}
