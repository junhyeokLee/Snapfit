import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../first_visit_controller.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// A one-time inline introduction, mounted only after the home journal loads.
class FirstHomeGuide extends ConsumerStatefulWidget {
  const FirstHomeGuide({
    super.key,
    required this.onRecord,
    required this.onCreate,
  });
  final VoidCallback onRecord, onCreate;

  @override
  ConsumerState<FirstHomeGuide> createState() => _FirstHomeGuideState();
}

class _FirstHomeGuideState extends ConsumerState<FirstHomeGuide> {
  bool _visible = false, _scheduled = false;
  late final FirstHomeGuideVisibility _visibility;

  @override
  void initState() {
    super.initState();
    _visibility = ref.read(firstHomeGuideVisibleProvider.notifier);
  }

  bool get _active =>
      TickerMode.of(context) && ModalRoute.isCurrentOf(context) != false;

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      if (!_active) {
        if (_visible) _close();
        return;
      }
      final replay =
          ref.read(firstVisitProvider).asData?.value.homeGuideRequested == true;
      if (!_visible && ref.read(firstVisitProvider.notifier).takeHomeGuide()) {
        setState(() => _visible = true);
        _visibility.setVisible(true);
        if (replay) {
          // A manual replay must reveal the guide within the retained scroll.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_visible || !_active) return;
            unawaited(
              Scrollable.ensureVisible(
                context,
                alignment: .2,
                duration: SnapFitMotion.duration(context, SnapFitMotion.fast),
                curve: SnapFitMotion.entrance,
              ),
            );
          });
        }
      }
    });
  }

  void _close() {
    setState(() => _visible = false);
    _visibility.setVisible(false);
  }

  void _finish(VoidCallback action) {
    // Ignore another tap while the previous action is opening its route.
    if (!_visible || !_active) return;
    _close();
    action();
  }

  @override
  void dispose() {
    if (_visible) {
      final visibility = _visibility;
      // Disposal can happen during a parent build. Publish only after it ends.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        visibility.setVisible(false);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(
      firstVisitProvider.select(
        (value) => value.asData?.value.shouldShowHomeGuide == true,
      ),
    );
    if ((_visible && !_active) || (pending && _active)) _schedule();
    if (!_visible || !_active) return const SizedBox.shrink();
    return Semantics(
      key: const ValueKey('first-home-guide'),
      container: true,
      liveRegion: true,
      label: '메인 사용 안내',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ExperienceFormStyle.selection(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '오늘의 한 장부터 시작해요',
                        style: ExperienceFormStyle.text(
                          context,
                          15,
                          weight: FontWeight.w600,
                        ).copyWith(height: 1.45),
                      ),
                    ),
                    IconButton(
                      tooltip: '안내 닫기',
                      onPressed: _close,
                      icon: const ExperienceIcon('X', size: 18),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '모은 사진은 앨범으로 엮을 수 있어요.',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ).copyWith(height: 1.5),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 0,
                  children: [
                    TextButton(
                      key: const ValueKey('first-home-guide-record'),
                      onPressed: () => _finish(widget.onRecord),
                      style: TextButton.styleFrom(
                        foregroundColor: ExperienceFormStyle.selectionInk(
                          context,
                        ),
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                        textStyle: ExperienceFormStyle.text(
                          context,
                          13,
                          weight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('오늘 기록하기'),
                    ),
                    TextButton(
                      key: const ValueKey('first-home-guide-create'),
                      onPressed: () => _finish(widget.onCreate),
                      style: TextButton.styleFrom(
                        foregroundColor: ExperienceFormStyle.muted(context),
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                        textStyle: ExperienceFormStyle.text(context, 12),
                      ),
                      child: const Text('앨범 바로 만들기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
