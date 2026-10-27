import 'package:flutter/material.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../views/referral_screen.dart';

class ReferralEntryCard extends StatelessWidget {
  const ReferralEntryCard({super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: ExperienceFormStyle.surface(context),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: const ValueKey('referral-entry'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: const WebAppRouteSettings(WebAppLocation.referral),
          builder: (_) => const ReferralScreen(),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.people_outline,
              color: ExperienceFormStyle.selectionInk(context),
              size: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '친구 초대',
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '친구와 함께, 100P씩 나눠 받아요.',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: ExperienceFormStyle.selectionInk(context),
            ),
          ],
        ),
      ),
    ),
  );
}
