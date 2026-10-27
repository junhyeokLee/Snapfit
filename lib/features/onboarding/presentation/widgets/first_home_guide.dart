import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/experience_form_style.dart';
import '../first_visit_controller.dart';

/// Only the small header anchor listens to onboarding state. No list rebuilds,
/// global keys, polling, screenshot captures, or permanent overlay entries.
class FirstHomeGuide extends ConsumerStatefulWidget {
  const FirstHomeGuide({
    super.key,
    required this.child,
    required this.onCreate,
  });
  final Widget child;
  final VoidCallback onCreate;

  @override
  ConsumerState<FirstHomeGuide> createState() => _FirstHomeGuideState();
}

class _FirstHomeGuideState extends ConsumerState<FirstHomeGuide> {
  final _portal = OverlayPortalController();
  bool _visible = false, _scheduled = false;

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
      if (!_visible && ref.read(firstVisitProvider.notifier).takeHomeGuide()) {
        setState(() => _visible = true);
        _portal.show();
      }
    });
  }

  void _close() {
    _portal.hide();
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(
      firstVisitProvider.select(
        (value) => value.asData?.value.shouldShowHomeGuide == true,
      ),
    );
    if ((_visible && !_active) || (pending && _active)) _schedule();
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        if (!_active) return const SizedBox.shrink();
        final target = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        final width = math.min(
          320.0,
          math.max(0.0, info.overlaySize.width - 32),
        );
        final left = (target.center.dx - width * .72)
            .clamp(16.0, math.max(16.0, info.overlaySize.width - width - 16))
            .toDouble();
        final top = target.bottom + 12;
        final height = math.max(0.0, info.overlaySize.height - top - 24);
        final arrow = (target.center.dx - left - 6)
            .clamp(18.0, math.max(18.0, width - 24))
            .toDouble();
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              child: Semantics(
                key: const ValueKey('first-home-guide'),
                container: true,
                liveRegion: true,
                label: '메인 사용 안내',
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: arrow,
                      top: -5,
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: ExperienceFormStyle.line(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 5,
                      shadowColor: Colors.black.withValues(alpha: .15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: ExperienceFormStyle.line(context),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: height),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '첫 앨범을 만들어볼까요?',
                                      style: ExperienceFormStyle.text(
                                        context,
                                        15,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '안내 닫기',
                                    onPressed: _close,
                                    icon: const Icon(Icons.close, size: 19),
                                  ),
                                ],
                              ),
                              Flexible(
                                child: SingleChildScrollView(
                                  primary: false,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        '이 + 버튼에서 새 앨범을 시작해요. 디자인을 고르거나 직접 꾸밀 수 있어요.',
                                        style: ExperienceFormStyle.text(
                                          context,
                                          13,
                                          secondary: true,
                                        ).copyWith(height: 1.65),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          TextButton(
                                            onPressed: _close,
                                            child: const Text('나중에'),
                                          ),
                                          FilledButton(
                                            key: const ValueKey(
                                              'first-home-guide-create',
                                            ),
                                            style: ExperienceFormStyle.primary(
                                              context,
                                            ),
                                            onPressed: () {
                                              _close();
                                              widget.onCreate();
                                            },
                                            child: const Text('앨범 만들기'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: _visible
              ? Border.all(
                  color: ExperienceFormStyle.selectionInk(context),
                  width: 1.5,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
