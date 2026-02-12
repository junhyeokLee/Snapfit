import 'package:flutter/material.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          '알림',
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Text(
          '알림이 없습니다.',
          style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
        ),
      ),
    );
  }
}
