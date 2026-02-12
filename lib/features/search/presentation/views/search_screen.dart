import 'package:flutter/material.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          '검색',
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Text(
          '검색 기능 준비 중입니다.',
          style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
        ),
      ),
    );
  }
}
