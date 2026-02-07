import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 확인/취소 다이얼로그. 삭제 등 위험한 액션 확인에 사용.
///
/// [showDeleteConfirm]을 사용하면 앨범 삭제용 기본 스타일로 표시됨.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final IconData? icon;
  final Color? iconBackgroundColor;
  final Color? iconColor;
  final bool isDestructive;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '취소',
    this.confirmText = '확인',
    this.icon,
    this.iconBackgroundColor,
    this.iconColor,
    this.isDestructive = false,
  });

  /// 앨범 삭제 확인 다이얼로그
  static ConfirmDialog deleteAlbum() => ConfirmDialog(
        title: '앨범 삭제',
        message: '이 앨범을 삭제하시겠어요?\n복구할 수 없습니다.',
        confirmText: '삭제',
        icon: Icons.delete_outline_rounded,
        iconBackgroundColor: const Color(0xFFFFEBEE),
        iconColor: const Color(0xFFE53935),
        isDestructive: true,
      );

  /// [showDeleteConfirm]과 동일한 스타일로 표시
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    IconData? icon,
    Color? iconBackgroundColor,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
        icon: icon,
        iconBackgroundColor: iconBackgroundColor,
        iconColor: iconColor,
        isDestructive: isDestructive,
      ),
    );
  }

  /// 앨범 삭제 확인 다이얼로그 표시
  static Future<bool?> showDeleteAlbum(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => ConfirmDialog.deleteAlbum(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + 0.2 * value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: 320.w),
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20.r,
                offset: Offset(0, 10.h),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor ?? Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32.sp,
                    color: iconColor ?? Colors.grey[700],
                  ),
                ),
                SizedBox(height: 20.h),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      text: cancelText,
                      onTap: () => Navigator.of(context).pop(false),
                      isPrimary: false,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _DialogButton(
                      text: confirmText,
                      onTap: () => Navigator.of(context).pop(true),
                      isPrimary: true,
                      isDestructive: isDestructive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  const _DialogButton({
    required this.text,
    required this.onTap,
    required this.isPrimary,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: isPrimary
                ? (isDestructive
                    ? null
                    : Colors.grey[100])
                : Colors.grey[100],
            gradient: isPrimary && isDestructive
                ? const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFC62828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: isPrimary && isDestructive
                ? [
                    BoxShadow(
                      color: const Color(0xFFE53935).withOpacity(0.3),
                      blurRadius: 8.r,
                      offset: Offset(0, 4.h),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: isPrimary && isDestructive
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
