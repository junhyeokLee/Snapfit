import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../viewmodels/album_editor_view_model.dart';

class DecorateColorTab extends ConsumerWidget {
  final Color surfaceColor;

  const DecorateColorTab({super.key, required this.surfaceColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = [
      Colors.white, const Color(0xFFEFEFEF), const Color(0xFFD9D9D9), const Color(0xFFB3B3B3),
      const Color(0xFF808080), Colors.black, const Color(0xFFFFEBEE), const Color(0xFFF3E5F5),
      const Color(0xFFE3F2FD), const Color(0xFFE8F5E9), const Color(0xFFFFFDE7), const Color(0xFFFFF3E0),
    ];

    return GridView.builder(
      padding: EdgeInsets.all(20.w),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            ref.read(albumEditorViewModelProvider.notifier).updatePageBackgroundColor(colors[index].value);
          },
          child: Container(
            decoration: BoxDecoration(
              color: colors[index],
              shape: BoxShape.circle,
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            ),
          ),
        );
      },
    );
  }
}
