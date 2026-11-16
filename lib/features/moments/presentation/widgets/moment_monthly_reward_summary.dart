import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../domain/moment_record.dart';

/// 서버가 확인한 인정 일수와 지급 상태만 보여 준다.
class MomentMonthlyRewardSummary extends StatelessWidget {
  const MomentMonthlyRewardSummary({super.key, required this.reward});

  final MomentMonthlyReward reward;

  String get _points => reward.points.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  void _showRules(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '월간 기록 보상',
              style: ExperienceFormStyle.text(
                context,
                22,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '한 달의 모든 날짜에 사진을 남기면\n${_points}P가 자동 적립돼요.',
              style: ExperienceFormStyle.text(context, 14),
            ),
            const SizedBox(height: 12),
            Text(
              '사진은 한국 시간 기준 당일에만 추가하거나 바꿀 수 있어요.',
              style: ExperienceFormStyle.text(context, 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final accent = ExperienceFormStyle.selectionInk(context);
    final title = reward.awarded
        ? '월간 기록 보상 ${_points}P 적립 완료'
        : reward.canComplete
        ? '한 달을 채우면 ${_points}P'
        : '기록은 계속 쌓이고 있어요';
    final status = reward.awarded
        ? '인정 기록 ${reward.recordedDays}/${reward.daysInMonth}일'
        : reward.canComplete
        ? '보상 인정 기록 ${reward.recordedDays}/${reward.daysInMonth}일'
        : '인정 기록 ${reward.recordedDays}/${reward.daysInMonth}일 · 이번 달 보상 마감';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        key: const ValueKey('home-monthly-reward'),
        onTap: () => _showRules(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExperienceIcon('Coins', size: 22, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const ValueKey('home-monthly-reward-title'),
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      key: const ValueKey('home-monthly-reward-status'),
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                  ],
                ),
              ),
              ExperienceIcon('ChevronRight', size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
