import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

// ── ... 더보기 바텀시트 ───────────────────────────────────────────
class AlbumReaderMoreOptionsSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onConfirm;
  final VoidCallback? onDelete; // null이면 메뉴에서 숨김 처리
  final VoidCallback? onInvite; // null이면 메뉴에서 숨김 처리
  final VoidCallback? onDetail; // null이면 메뉴에서 숨김 처리
  final bool compact;

  const AlbumReaderMoreOptionsSheet({
    super.key,
    required this.onEdit,
    required this.onConfirm,
    this.onDelete,
    this.onInvite,
    this.onDetail,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: compact
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(compact ? 18.r : 24.r),
        border: compact
            ? Border.all(
                color: SnapFitColors.textMutedOf(context).withOpacity(0.10),
              )
            : null,
        boxShadow: compact
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: !compact,
        bottom: !compact,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              SizedBox(height: 8.h),
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: SnapFitColors.textMutedOf(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),
            ] else
              SizedBox(height: 8.h),

            // 상세보기 (onDetail이 전달되었을 때만 노출)
            if (onDetail != null) ...[
              _SheetItem(
                icon: Icons.zoom_in_rounded,
                label: '상세보기',
                onTap: onDetail!,
                compact: compact,
              ),
              Divider(
                height: 1,
                color: SnapFitColors.textMutedOf(context).withOpacity(0.1),
                indent: 20.w,
                endIndent: 20.w,
              ),
            ],

            // 수정하기
            _SheetItem(
              icon: Icons.edit_note_rounded,
              label: '수정하기',
              onTap: onEdit,
              compact: compact,
            ),

            Divider(
              height: 1,
              color: SnapFitColors.textMutedOf(context).withOpacity(0.1),
              indent: 20.w,
              endIndent: 20.w,
            ),

            // 초대하기 (onInvite가 전달되었을 때만 노출)
            if (onInvite != null) ...[
              _SheetItem(
                icon: Icons.group_add_rounded,
                label: '초대하기',
                onTap: onInvite!,
                compact: compact,
              ),
              Divider(
                height: 1,
                color: SnapFitColors.textMutedOf(context).withOpacity(0.1),
                indent: 20.w,
                endIndent: 20.w,
              ),
            ],

            // 제작 확정
            _SheetItem(
              icon: Icons.lock_outline_rounded,
              label: '제작 확정하기',
              iconColor: SnapFitColors.accent,
              labelColor: SnapFitColors.accent,
              onTap: onConfirm,
              compact: compact,
            ),

            if (onDelete != null) ...[
              Divider(
                height: 1,
                color: SnapFitColors.textMutedOf(context).withOpacity(0.1),
                indent: 20.w,
                endIndent: 20.w,
              ),
              _SheetItem(
                icon: Icons.delete_outline_rounded,
                label: '삭제하기',
                iconColor: Colors.redAccent,
                labelColor: Colors.redAccent,
                onTap: onDelete!,
                compact: compact,
              ),
            ],

            SizedBox(height: compact ? 8.h : 8.h),
          ],
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool compact;

  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = labelColor ?? SnapFitColors.textPrimaryOf(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14.w : 24.w,
          vertical: compact ? 10.h : 18.h,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? SnapFitColors.textSecondaryOf(context),
              size: compact ? 18.sp : 22.sp,
            ),
            SizedBox(width: compact ? 10.w : 16.w),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 13.sp : 16.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 원형 아이콘 버튼 ──────────────────────────────────────────────
class AlbumReaderCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const AlbumReaderCircleBtn({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20.sp),
      ),
    );
  }
}
