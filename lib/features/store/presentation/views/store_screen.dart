import 'package:flutter/material.dart';
import '../../../../core/constants/snapfit_colors.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: Center(
        child: Text(
          '스토어 준비 중입니다.',
          style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
        ),
      ),
    );
  }
}
