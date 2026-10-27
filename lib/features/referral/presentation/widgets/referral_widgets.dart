import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';

String referralPoints(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

class ReferralRewardCard extends StatelessWidget {
  const ReferralRewardCard({
    super.key,
    required this.inviterPoints,
    required this.inviteePoints,
    required this.registrationWindowDays,
  });
  final int inviterPoints, inviteePoints, registrationWindowDays;

  @override
  Widget build(BuildContext context) => ReferralPaper(
    tint: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: SocialStyle.paper(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: SocialStyle.line(context)),
              ),
              child: Icon(
                Icons.people_outline,
                size: 33,
                color: SocialStyle.accent(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '함께 남길 추억이\n더 많아지도록',
          style: ExperienceFormStyle.text(
            context,
            29,
            weight: FontWeight.w600,
          ).copyWith(height: 1.3, letterSpacing: -.6),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _RewardLabel(label: '초대한 나', points: inviterPoints),
            _RewardLabel(label: '함께 온 친구', points: inviteePoints),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '친구가 가입 후 $registrationWindowDays일 안에 내 코드를 등록하면 두 사람 모두 포인트를 받아요.',
          style: ExperienceFormStyle.text(
            context,
            14,
            secondary: true,
          ).copyWith(height: 1.7),
        ),
      ],
    ),
  );
}

class _RewardLabel extends StatelessWidget {
  const _RewardLabel({required this.label, required this.points});
  final String label;
  final int points;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    decoration: BoxDecoration(
      color: SocialStyle.paper(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        const SizedBox(height: 5),
        Text(
          '+${referralPoints(points)}P',
          style: ExperienceFormStyle.text(
            context,
            24,
            weight: FontWeight.w600,
            color: SocialStyle.accent(context),
          ),
        ),
      ],
    ),
  );
}

class ReferralShareCard extends StatelessWidget {
  const ReferralShareCard({
    super.key,
    required this.code,
    required this.onCopyCode,
    required this.onCopyLink,
    required this.onShare,
    required this.busy,
  });
  final String code;
  final VoidCallback onCopyCode, onCopyLink, onShare;
  final bool busy;

  @override
  Widget build(BuildContext context) => ReferralPaper(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '나의 초대 코드',
          style: ExperienceFormStyle.text(context, 19, weight: FontWeight.w600),
        ),
        const SizedBox(height: 9),
        Text(
          '함께 기록하고 싶은 친구에게 보내주세요.',
          style: ExperienceFormStyle.text(
            context,
            14,
            secondary: true,
          ).copyWith(height: 1.6),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: SocialStyle.background(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SocialStyle.line(context)),
          ),
          child: SelectableText(
            code,
            key: const ValueKey('referral-own-code'),
            textAlign: TextAlign.center,
            style: ExperienceFormStyle.text(
              context,
              25,
              weight: FontWeight.w600,
            ).copyWith(letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey('referral-share'),
          style: SocialStyle.primary(
            context,
          ).copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 54))),
          onPressed: busy ? null : onShare,
          icon: const Icon(Icons.ios_share_rounded, size: 19),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Text('친구 초대하기', textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            TextButton.icon(
              key: const ValueKey('referral-copy-code'),
              onPressed: busy ? null : onCopyCode,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('코드 복사'),
            ),
            TextButton.icon(
              key: const ValueKey('referral-copy-link'),
              onPressed: busy ? null : onCopyLink,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('링크 복사'),
            ),
          ],
        ),
      ],
    ),
  );
}

class ReferralSummaryCard extends StatelessWidget {
  const ReferralSummaryCard({
    super.key,
    required this.monthlyRewardedCount,
    required this.rewardLimit,
    required this.invitedCount,
    required this.totalEarned,
  });
  final int monthlyRewardedCount, rewardLimit, invitedCount, totalEarned;

  @override
  Widget build(BuildContext context) => ReferralPaper(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '함께 쌓은 기록',
          style: ExperienceFormStyle.text(context, 19, weight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 28,
          runSpacing: 20,
          children: [
            _SummaryNumber(label: '초대한 친구', value: '$invitedCount명'),
            _SummaryNumber(
              label: '초대로 모은 포인트',
              value: '${referralPoints(totalEarned)}P',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: SocialStyle.line(context)),
        const SizedBox(height: 16),
        Text(
          '이번 달 초대 보상 $monthlyRewardedCount / $rewardLimit명',
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
        const SizedBox(height: 8),
        Text(
          '초대 보상은 한국 시간 기준 매월 $rewardLimit명까지 받을 수 있어요.',
          style: ExperienceFormStyle.text(
            context,
            12,
            secondary: true,
          ).copyWith(height: 1.6),
        ),
      ],
    ),
  );
}

class _SummaryNumber extends StatelessWidget {
  const _SummaryNumber({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: ExperienceFormStyle.text(context, 24, weight: FontWeight.w600),
      ),
    ],
  );
}

class ReferralRedeemCard extends StatelessWidget {
  const ReferralRedeemCard({
    super.key,
    required this.controller,
    required this.points,
    required this.busy,
    required this.enabled,
    required this.onRedeem,
    required this.onChanged,
    this.error,
    this.eligibleUntil,
  });
  final TextEditingController controller;
  final int points;
  final bool busy, enabled;
  final VoidCallback onRedeem;
  final ValueChanged<String> onChanged;
  final String? error;
  final DateTime? eligibleUntil;

  @override
  Widget build(BuildContext context) {
    final deadline = eligibleUntil?.toUtc().add(const Duration(hours: 9));
    return ReferralPaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '친구에게 초대받았나요?',
            style: ExperienceFormStyle.text(
              context,
              19,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '친구 코드를 등록하고 ${referralPoints(points)}P를 받아요. 코드는 한 번만 등록할 수 있어요.',
            style: ExperienceFormStyle.text(
              context,
              14,
              secondary: true,
            ).copyWith(height: 1.6),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('referral-code-input'),
            controller: controller,
            enabled: !busy,
            onChanged: onChanged,
            onSubmitted: (_) {
              if (enabled && !busy) onRedeem();
            },
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: '친구 초대 코드',
              hintText: '받은 코드를 입력해 주세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                key: const ValueKey('referral-redeem-error'),
                style: ExperienceFormStyle.text(
                  context,
                  13,
                  color: Theme.of(context).colorScheme.error,
                ).copyWith(height: 1.6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('referral-redeem'),
            style: SocialStyle.primary(
              context,
            ).copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 54))),
            onPressed: enabled && !busy ? onRedeem : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                busy ? '코드 확인 중…' : '등록하고 ${referralPoints(points)}P 받기',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (deadline != null) ...[
            const SizedBox(height: 12),
            Text(
              '${deadline.month}월 ${deadline.day}일 ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}까지 등록할 수 있어요. (한국 시간)',
              style: ExperienceFormStyle.text(
                context,
                12,
                secondary: true,
              ).copyWith(height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}

class ReferralPaper extends StatelessWidget {
  const ReferralPaper({super.key, required this.child, this.tint = false});
  final Widget child;
  final bool tint;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tint
          ? Color.alphaBlend(
              SocialStyle.accent(context).withValues(alpha: .075),
              SocialStyle.paper(context),
            )
          : SocialStyle.paper(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: SocialStyle.line(context)),
    ),
    child: Padding(padding: const EdgeInsets.all(22), child: child),
  );
}
