import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart';
import 'creation_workspace.dart';
import '../../../ai_album/domain/ai_template_job.dart';

class AiTemplateGeneratingStep extends StatefulWidget {
  const AiTemplateGeneratingStep({
    super.key,
    this.cover,
    this.innerPageCount,
    this.requestStartedAt,
    this.job,
    this.onPause,
    this.onRefresh,
  });
  final CoverSize? cover;
  final int? innerPageCount;
  final AiTemplateJob? job;
  final VoidCallback? onPause;
  final VoidCallback? onRefresh;

  /// The request owner supplies this so resizing cannot restart the wait notice.
  final DateTime? requestStartedAt;

  @override
  State<AiTemplateGeneratingStep> createState() =>
      _AiTemplateGeneratingStepState();
}

class _AiTemplateGeneratingStepState extends State<AiTemplateGeneratingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  Timer? _longWaitTimer;
  bool _longWait = false;

  void _scheduleWaitNotice() {
    _longWaitTimer?.cancel();
    final startedAt = widget.requestStartedAt ?? DateTime.now();
    final remaining = startedAt
        .add(const Duration(seconds: 30))
        .difference(DateTime.now());
    _longWait = remaining <= Duration.zero;
    if (!_longWait) {
      _longWaitTimer = Timer(remaining, () {
        if (mounted) setState(() => _longWait = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AiTemplateGeneratingStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestStartedAt != widget.requestStartedAt) {
      _scheduleWaitNotice();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SnapFitMotion.reduced(context) || !TickerMode.of(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scheduleWaitNotice();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _longWaitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 48),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (context, box) {
                  final bookArea = ExcludeSemantics(
                    child: _ShimmerStage(
                      shimmer: _shimmer,
                      child: CreationPaperStage(
                        title: 'AI 디자인 요청 중',
                        detail: widget.innerPageCount == null
                            ? null
                            : '표지 · 내지 ${widget.innerPageCount}쪽',
                        child: CreationBlankBook(
                          cover: widget.cover ?? defaultCoverSize,
                          title: '새로운 이야기',
                        ),
                      ),
                    ),
                  );
                  final statusArea = _StatusArea(
                    longWait: _longWait,
                    animation: _shimmer,
                    job: widget.job,
                    onPause: widget.onPause,
                    onRefresh: widget.onRefresh,
                  );
                  return MediaQuery.orientationOf(context) ==
                              Orientation.landscape &&
                          box.maxWidth >= 600 &&
                          MediaQuery.textScalerOf(context).scale(14) <= 25.2
                      ? Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: math.max(
                                  120,
                                  constraints.maxHeight - 48,
                                ),
                                child: bookArea,
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(child: statusArea),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: math.max(
                                120,
                                math.min(280, constraints.maxHeight * .4),
                              ),
                              child: bookArea,
                            ),
                            const SizedBox(height: 36),
                            statusArea,
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 책 스테이지 위로 shimmer 광택이 흐르는 래퍼
class _ShimmerStage extends StatelessWidget {
  const _ShimmerStage({required this.shimmer, required this.child});
  final Animation<double> shimmer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (SnapFitMotion.reduced(context)) return child;
    final dark = SnapFitColors.isDark(context);
    // 다크모드: 흰 shimmer가 너무 강하게 보이므로 절반 이하로 줄임
    final peak = dark ? 0.10 : 0.22;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: shimmer,
              builder: (context, _) {
                final t = shimmer.value;
                final x = t * 3.2 - 1.6;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(x - 0.6, -1),
                      end: Alignment(x + 0.6, 1),
                      colors: [
                        Colors.white.withOpacity(0),
                        Colors.white.withOpacity(peak),
                        Colors.white.withOpacity(0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Only the request's observed waiting state is shown, never timed model stages.
class _StatusArea extends StatelessWidget {
  const _StatusArea({
    required this.longWait,
    required this.animation,
    this.job,
    this.onPause,
    this.onRefresh,
  });
  final bool longWait;
  final Animation<double> animation;
  final AiTemplateJob? job;
  final VoidCallback? onPause;
  final VoidCallback? onRefresh;

  String get observedTitle => job?.state == AiTemplateJobState.waiting
      ? '다음 작업 시간을 기다리고 있어요'
      : switch (job?.stage) {
          'direction' => '책의 디자인 방향을 정리하고 있어요',
          'composition' => '펼침면을 구성하고 있어요',
          'review' => '글과 인쇄 구성을 확인하고 있어요',
          _ =>
            job?.state == AiTemplateJobState.queued
                ? '디자인 요청이 접수됐어요'
                : longWait
                ? '응답이 늦어지고 있어요'
                : 'AI 디자인 요청 중',
        };

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: SnapFitMotion.reduced(context)
            ? _dots(0)
            : AnimatedBuilder(
                animation: animation,
                builder: (_, __) => _dots(animation.value),
              ),
      ),
      const SizedBox(height: 24),
      Semantics(
        key: const ValueKey('ai-generation-status'),
        liveRegion: true,
        child: Text(
          observedTitle,
          textAlign: TextAlign.center,
          style: ExperienceFormStyle.text(context, 20, weight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        job != null
            ? '앱을 닫아도 서버에서 이어서 진행해요. 잠시 기다려야 할 때는 무료 이용 한도에 맞춰 다시 시도해요. 새 요청을 만들지 않고 이 요청의 상태만 확인하고 있어요.'
            : longWait
            ? '아직 처리 결과를 받지 못했어요. 새 요청을 보내지 않고 현재 요청을 기다리고 있어요.'
            : '요청한 디자인의 처리 결과를 기다리고 있어요. 준비되면 결과를 검토할 수 있어요.',
        key: const ValueKey('ai-generation-wait-detail'),
        textAlign: TextAlign.center,
        style: ExperienceFormStyle.text(context, 14, secondary: true),
      ),
      if (job != null && job!.completedStages > 0) ...[
        const SizedBox(height: 12),
        Text(
          '완료한 작업 ${job!.completedStages}개',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      ],
      if (job?.state == AiTemplateJobState.waiting &&
          job?.nextAttemptAt != null) ...[
        const SizedBox(height: 12),
        Text(
          '다음 시도 ${_nextAttemptLabel(job!.nextAttemptAt!)} · 그때까지는 자주 확인하지 않아요.',
          textAlign: TextAlign.center,
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      ],
      if (onRefresh != null)
        TextButton(
          key: const ValueKey('ai-generation-refresh'),
          onPressed: onRefresh,
          child: const Text('진행 상황 확인'),
        ),
      if (onPause != null) ...[
        const SizedBox(height: 16),
        TextButton.icon(
          key: const ValueKey('ai-generation-pause'),
          onPressed: onPause,
          icon: const Icon(Icons.schedule_outlined, size: 18),
          label: const Text('나중에 확인'),
        ),
      ],
      const SizedBox(height: 20),
      Text(
        '요청만으로 포인트를 차감하지 않아요. 결과를 확인하고 사용하면 무료 혜택이나 포인트가 적용돼요.',
        textAlign: TextAlign.center,
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
    ],
  );

  String _nextAttemptLabel(DateTime at) {
    final local = at.toLocal();
    return '${local.month}월 ${local.day}일 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _dots(double value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 7),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SnapFitColors.accent.withValues(
              alpha:
                  .45 + .4 * (1 + math.sin((value - i / 3) * math.pi * 2)) / 2,
            ),
          ),
        ),
      ],
    ],
  );
}
