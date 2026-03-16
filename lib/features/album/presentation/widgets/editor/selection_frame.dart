import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

enum ResizeHandlePosition { topLeft, topRight, bottomLeft, bottomRight }

class SelectionFrame extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final bool showHandles;
  final VoidCallback? onDelete;
  final Function(ScaleStartDetails)? onScaleStart;
  final Function(ScaleUpdateDetails)? onScaleUpdate;
  final Function(ScaleEndDetails)? onScaleEnd;
  final void Function(ResizeHandlePosition pos, DragStartDetails details)?
  onResizeStart;
  final void Function(ResizeHandlePosition pos, DragUpdateDetails details)?
  onResizeUpdate;
  final void Function(ResizeHandlePosition pos, DragEndDetails details)?
  onResizeEnd;

  const SelectionFrame({
    super.key,
    required this.child,
    required this.isSelected,
    this.onDelete,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.showHandles = true,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
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

        // Corners (Visual Anchors)
        if (showHandles) ...[
          _buildCorner(pos: ResizeHandlePosition.topLeft, top: -4, left: -4),
          _buildCorner(pos: ResizeHandlePosition.topRight, top: -4, right: -4),
          _buildCorner(
            pos: ResizeHandlePosition.bottomLeft,
            bottom: -4,
            left: -4,
          ),
          _buildCorner(
            pos: ResizeHandlePosition.bottomRight,
            bottom: -4,
            right: -4,
          ),
        ],
      ],
    );
  }

  Widget _buildCorner({
    required ResizeHandlePosition pos,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: GestureDetector(
        onPanStart: onResizeStart == null
            ? null
            : (details) => onResizeStart!(pos, details),
        onPanUpdate: onResizeUpdate == null
            ? null
            : (details) => onResizeUpdate!(pos, details),
        onPanEnd: onResizeEnd == null
            ? null
            : (details) => onResizeEnd!(pos, details),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: SnapFitColors.accent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle({
    required IconData icon,
    Function(DragUpdateDetails)? onPanUpdate,
  }) {
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
