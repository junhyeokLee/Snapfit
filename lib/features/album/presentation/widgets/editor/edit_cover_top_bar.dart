import 'package:flutter/material.dart';

import '../../../../../core/constants/snapfit_colors.dart';

/// EditCover 전용 상단 액션 바
class EditCoverTopBar extends StatelessWidget {
  final bool isCreating;
  final bool isEditMode;
  final VoidCallback onAction;

  const EditCoverTopBar({
    super.key,
    required this.isCreating,
    required this.isEditMode,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SnapFitColors.backgroundOf(context),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: SnapFitColors.accent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size(64, 32),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: isCreating ? null : onAction,
                  child: Text(
                    !isEditMode ? '완료' : '다음',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
