import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

enum EditorMode {
  none,
  layout, // 슬롯 기반 레이아웃(페이지 템플릿)
  template, // 전체 디자인 템플릿 (확장용)
  sticker,
  backgroundColor,
  layer,
  text, // For text editing, though usually handled by dialog/overlay
}

class EditorBottomMenu extends StatelessWidget {
  final EditorMode currentMode;
  final Function(EditorMode) onModeChanged;
  final VoidCallback? onAddPhoto;
  final bool isCover;
  final VoidCallback? onCover;
  final bool showCoverMenuItem;

  const EditorBottomMenu({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.onAddPhoto,
    this.isCover = false,
    this.onCover,
    this.showCoverMenuItem = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76.h,
      padding: EdgeInsets.only(bottom: 16.h), // 하단 여백 살짝 줄여서 더 컴팩트하게
      decoration: BoxDecoration(
        color: Colors.transparent, // 상위 그라데이션 배경 그대로 사용
        border: Border(
          top: BorderSide(
            color: SnapFitColors.overlayLightOf(context),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: isCover
            // 커버 편집 시: 커버(테마) + 레이아웃 + 템플릿 모두 제공
            ? [
                _buildMenuItem(
                  context,
                  '글쓰기',
                  Icons.text_fields_outlined,
                  EditorMode.text,
                ),
                _buildMenuItem(
                  context,
                  '사진',
                  Icons.photo_outlined,
                  EditorMode.none,
                  isAction: true,
                  onAction: onAddPhoto,
                ),
                if (showCoverMenuItem)
                  _buildMenuItem(
                    context,
                    '커버',
                    Icons.photo_album_outlined,
                    EditorMode.none,
                    isAction: true,
                    onAction: onCover,
                  ),
                _buildMenuItem(
                  context,
                  '레이아웃',
                  Icons.dashboard_outlined,
                  EditorMode.layout,
                ),
                _buildMenuItem(
                  context,
                  '템플릿',
                  Icons.auto_awesome_outlined,
                  EditorMode.template,
                ),
                _buildMenuItem(
                  context,
                  '스티커',
                  Icons.emoji_emotions_outlined,
                  EditorMode.sticker,
                ),
                _buildMenuItem(
                  context,
                  '배경색상',
                  Icons.palette_outlined,
                  EditorMode.backgroundColor,
                ),
                _buildMenuItem(
                  context,
                  '레이어',
                  Icons.layers_outlined,
                  EditorMode.layer,
                ),
              ]
            // 내지 편집 시도 동일하게 레이아웃 + 템플릿 제공
            : [
                _buildMenuItem(
                  context,
                  '글쓰기',
                  Icons.text_fields_outlined,
                  EditorMode.text,
                ),
                _buildMenuItem(
                  context,
                  '사진',
                  Icons.photo_outlined,
                  EditorMode.none,
                  isAction: true,
                  onAction: onAddPhoto,
                ),
                _buildMenuItem(
                  context,
                  '레이아웃',
                  Icons.dashboard_outlined,
                  EditorMode.layout,
                ),
                _buildMenuItem(
                  context,
                  '템플릿',
                  Icons.auto_awesome_outlined,
                  EditorMode.template,
                ),
                _buildMenuItem(
                  context,
                  '스티커',
                  Icons.emoji_emotions_outlined,
                  EditorMode.sticker,
                ),
                _buildMenuItem(
                  context,
                  '배경색상',
                  Icons.palette_outlined,
                  EditorMode.backgroundColor,
                ),
                _buildMenuItem(
                  context,
                  '레이어',
                  Icons.layers_outlined,
                  EditorMode.layer,
                ),
              ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String label,
    IconData icon,
    EditorMode mode, {
    bool isAction = false,
    VoidCallback? onAction,
  }) {
    final isSelected = !isAction && currentMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 바텀 아이콘/텍스트 색상: 라이트 모드 = 검정, 다크 모드 = 흰색
    final Color color = isDark ? Colors.white : Colors.black;

    return InkWell(
      onTap: () {
        if (isAction) {
          onAction?.call();
        } else {
          onModeChanged(isSelected ? EditorMode.none : mode);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(height: 4.h),
          Text(
            label,
            // 앱 전역 텍스트 테마(bodySmall)를 베이스로 사용해 폰트/라인하이트를 통일하고,
            // 크기·두께만 하단 메뉴용으로 살짝 조정한다.
            style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
                .copyWith(
                  fontSize: 9.sp,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.1,
                ),
          ),
        ],
      ),
    );
  }
}
