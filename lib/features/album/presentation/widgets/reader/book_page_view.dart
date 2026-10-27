import 'package:flutter/material.dart';

/// 앨범 뷰어 전용 커스텀 PageView
///
/// 페이지 전환 물리 엔진 속도 및 현재 페이지 오프셋 상태를 제공합니다.
class BookPageView extends StatefulWidget {
  final int itemCount;
  final PageController pageController;
  final Widget Function(BuildContext context, int index, double pageOffset)
  itemBuilder;
  final ValueChanged<int>? onPageChanged;

  const BookPageView({
    super.key,
    required this.itemCount,
    required this.pageController,
    required this.itemBuilder,
    this.onPageChanged,
  });

  @override
  State<BookPageView> createState() => _BookPageViewState();
}

class _BookPageViewState extends State<BookPageView> {
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.pageController.hasClients
        ? (widget.pageController.page ??
              widget.pageController.initialPage.toDouble())
        : widget.pageController.initialPage.toDouble();
    widget.pageController.addListener(_onPageScroll);
  }

  @override
  void didUpdateWidget(covariant BookPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController == widget.pageController) return;
    oldWidget.pageController.removeListener(_onPageScroll);
    widget.pageController.addListener(_onPageScroll);
    // PageView transfers its existing position to the replacement controller.
    // Preserve that offset rather than resetting to the new initialPage.
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageScroll);
    super.dispose();
  }

  void _onPageScroll() {
    if (widget.pageController.hasClients) {
      setState(() => _currentPage = widget.pageController.page ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.pageController,
      itemCount: widget.itemCount,
      physics: const _BookPagePhysics(),
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) {
        final double pageOffset = index - _currentPage;
        return widget.itemBuilder(context, index, pageOffset);
      },
    );
  }
}

// ── 페이지 넘김 물리 ──────────────────────────────────────────────
/// 책 넘기기 무게감 표현을 위해 스크롤 속도 살짝 둔화
class _BookPagePhysics extends PageScrollPhysics {
  const _BookPagePhysics({super.parent});

  @override
  _BookPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _BookPagePhysics(parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 0.60: 일반 PageView보다 살짝 느려 책 무게감 표현
    return super.applyPhysicsToUserOffset(position, offset * 0.60);
  }
}
