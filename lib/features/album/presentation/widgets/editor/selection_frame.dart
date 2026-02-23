import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

class SelectionFrame extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final bool showHandles;
  final VoidCallback? onDelete;
  final Function(ScaleStartDetails)? onScaleStart;
  final Function(ScaleUpdateDetails)? onScaleUpdate;
  final Function(ScaleEndDetails)? onScaleEnd;

  const SelectionFrame({
    super.key,
    required this.child,
    required this.isSelected,
    this.onDelete,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.showHandles = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSelected) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Content with Border
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? SnapFitColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
        
        // Top-Center Rotate Handle
        if (showHandles)
          Positioned(
            top: -24,
            left: 0,
            right: 0,
            child: Center(
              child: _buildHandle(
                icon: Icons.refresh,
                onPanUpdate: (details) {
                   // TODO: Implement rotation logic if needed via this handle
                   // For now, relies on 2-finger gesture, but visual handle is requested
                }
              ),
            ),
          ),

        // Bottom-Center Delete Handle
        if (showHandles)
          Positioned(
            bottom: -24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        
        // Corners (Visual Anchors)
        if (showHandles) ...[
          _buildCorner(top: -4, left: -4),
          _buildCorner(top: -4, right: -4),
          _buildCorner(bottom: -4, left: -4),
          _buildCorner(bottom: -4, right: -4),
        ],
      ],
    );
  }

  Widget _buildCorner({double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: SnapFitColors.accent, width: 2),
        ),
      ),
    );
  }

  Widget _buildHandle({required IconData icon, Function(DragUpdateDetails)? onPanUpdate}) {
    return GestureDetector(
       onPanUpdate: onPanUpdate,
       child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: SnapFitColors.accent, width: 1.5),
           boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 14, color: SnapFitColors.accent),
      ),
    );
  }
}
