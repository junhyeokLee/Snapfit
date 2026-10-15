import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/web/web_design.dart';

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
    if (kIsWeb) {
      Widget action(String label, IconData icon, VoidCallback onTap,
          {bool destructive = false}) => ListTile(
        leading: Icon(icon, size: 19,
          color: destructive ? Theme.of(context).colorScheme.error : WebPalette.of(context).muted),
        title: Text(label, style: TextStyle(
          fontSize: 14,
          color: destructive ? Theme.of(context).colorScheme.error : WebPalette.of(context).ink,
        )),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      );
      return Material(
        color: WebPalette.of(context).surface,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
                child: Row(children: [
                  Expanded(child: Text('앨범 관리', style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: WebPalette.of(context).ink,
                  ))),
                  IconButton(
                    tooltip: '메뉴 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ]),
              ),
              Divider(height: 1, color: WebPalette.of(context).line),
              if (onDetail != null) action('페이지 상세', Icons.zoom_in, onDetail!),
              action('앨범 편집', Icons.edit_outlined, onEdit),
              if (onInvite != null)
                action('멤버 초대', Icons.group_add_outlined, onInvite!),
              action('책 주문 준비', Icons.auto_stories_outlined, onConfirm),
              if (onDelete != null) ...[
                Divider(height: 1, color: WebPalette.of(context).line),
                action('앨범 삭제', Icons.delete_outline, onDelete!, destructive: true),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }
    final media = MediaQuery.of(context);
    final maxSheetHeight = media.size.height * (compact ? 0.72 : 0.82);
    final radius = compact ? 16.0 : 24.r;
    return Container(
      margin: compact
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(radius),
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
        minimum: EdgeInsets.only(bottom: compact ? 0 : 10),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                const SizedBox(height: 6),
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

              SizedBox(height: compact ? 6 : 12.h),
            ],
          ),
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
    final horizontalPadding = compact ? 14.0 : 24.w;
    final verticalPadding = compact ? 8.5 : 18.h;
    final iconSize = compact ? 17.5 : 22.sp;
    final gap = compact ? 10.0 : 16.w;
    final fontSize = compact ? 13.0 : 16.sp;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? SnapFitColors.textSecondaryOf(context),
              size: iconSize,
            ),
            SizedBox(width: gap),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
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
          color: AlbumStageStyle.glass(context),
          shape: BoxShape.circle,
          border: Border.all(color: AlbumStageStyle.line(context)),
        ),
        child: Icon(icon, color: AlbumStageStyle.ink(context), size: 20.sp),
      ),
    );
  }
}
