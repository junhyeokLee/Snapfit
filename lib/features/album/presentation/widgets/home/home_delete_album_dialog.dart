import 'package:flutter/material.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/experience_icon.dart';

/// 앨범 삭제 확인 다이얼로그
class HomeDeleteAlbumDialog extends StatelessWidget {
  const HomeDeleteAlbumDialog({super.key});

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
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: SnapFitColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: SnapFitColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const ExperienceIcon(
                  'Trash2',
                  size: 32,
                  color: SnapFitColors.error,
                ),
              ),
              const SizedBox(height: 20),
              // 제목
              Text(
                '앨범 삭제',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 12),
              // 내용
              Text(
                '이 앨범을 삭제하시겠어요?\n함께 작업한 친구도 더 이상 접근할 수 없고,\n삭제한 앨범은 복구할 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: SnapFitColors.textSecondaryOf(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // 버튼들
              Row(
                children: [
                  // 취소 버튼
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: SnapFitColors.backgroundOf(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '취소',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: SnapFitColors.textPrimaryOf(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 삭제 버튼
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                SnapFitColors.error,
                                SnapFitColors.errorDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: SnapFitColors.error.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            '삭제',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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
