import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

/// 책 넘기는 3D 페이지 전환 PageView
///
/// 페이지 구성:
///   index 0          : 커버 → 바로 슬라이드
///   index 1↔2        : 페이지 쌍 내부 슬라이드
///   index 2→3, 4→5…  : 스프레드 경계 → 실제 책 넘기기 3D Flip
class BookPageView extends StatefulWidget {
  final int itemCount;
  final PageController pageController;
  final Widget Function(BuildContext context, int index) itemBuilder;
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
    widget.pageController.addListener(_onPageScroll);
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
        return _BookPageItem(
          index: index,
          currentPage: _currentPage,
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

// ── 개별 페이지 변환 위젯 ───────────────────────────────────────────
// StatefulWidget: AnimatedOpacity가 자체 애니메이션 상태를 유지해야
// 위젯 트리를 유지(마운트/언마운트 없이)하면서 부드럽게 페이드
class _BookPageItem extends StatefulWidget {
  final int index;
  final double currentPage;
  final Widget child;

  const _BookPageItem({
    required this.index,
    required this.currentPage,
    required this.child,
    super.key,
  });

  @override
  State<_BookPageItem> createState() => _BookPageItemState();
}

class _BookPageItemState extends State<_BookPageItem> {
  /// 페이지 index의 쌍 번호 반환
  /// - index 0 (커버) → pair 0 (단독)
  /// - index 1,2 → pair 1 / index 3,4 → pair 2 ...
  static int _pairOf(int pageIndex) {
    if (pageIndex <= 0) return 0;
    return ((pageIndex - 1) ~/ 2) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final double pageOffset = widget.index - widget.currentPage;
    final double absOffset  = pageOffset.abs().clamp(0.0, 2.0);
    final int floorPage = widget.currentPage.floor();
    final int ceilPage  = widget.currentPage.ceil();

    final int myPair    = _pairOf(widget.index);
    final int floorPair = _pairOf(floorPage);
    final int ceilPair  = _pairOf(ceilPage);

    // 이 페이지가 보여야 하는지 + 어떤 변환을 적용할지 결정
    bool shouldHide;
    bool isFlip = false;

    // ── 커버 정착 중 ─────────────────────────────────────────────────
    if (widget.currentPage < 0.10) {
      shouldHide = widget.index != 0;
      isFlip = false;
    }
    // ── 쌍 경계 전환(커버↔1, 2↔3, 4↔5 …): 3D flip ─────────────────
    else {
      final bool isCrossPair = floorPair != ceilPair;
      if (isCrossPair) {
        final bool involved = widget.index == floorPage || widget.index == ceilPage;
        shouldHide = !involved;
        isFlip = true;
      }
      // ── 같은 쌍 내부(1↔2, 3↔4 …): 슬라이드 + peek ─────────────────
      else if (myPair == floorPair) {
        shouldHide = false;
        isFlip = false;
      }
      // ── 쌍이 다름: 숨김 ───────────────────────────────────────────
      else {
        shouldHide = true;
        isFlip = false;
      }
    }

    // ── 통합 위젯 트리 구성 변수 ─────────────────────────────────────
    // pageOffset < 0 : 다음 페이지 (오른쪽) / > 0 : 이전 페이지 (왼쪽)
    final bool isNextPage = pageOffset < 0;

    Alignment alignment;
    Matrix4 matrix;
    double scale = 1.0;
    double opacity = 1.0;
    double shadowAlpha = 0.0;
    Alignment shadowBegin = isNextPage ? Alignment.centerLeft : Alignment.centerRight;
    Alignment shadowEnd = isNextPage ? Alignment.centerRight : Alignment.centerLeft;

    if (isFlip) {
      // ② 실제 책 넘기기: spine 기준 회전 + 투명도 + 그림자 오버레이
      alignment = isNextPage ? Alignment.centerLeft : Alignment.centerRight;
      final double angle = absOffset * math.pi * 0.42;
      final double rotY = isNextPage ? angle : -angle;

      matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0020)
        ..rotateY(rotY);

      shadowAlpha = (math.sin(angle) * 0.55).clamp(0.0, 0.55);
    } else {
      // ③ 슬라이드: 가벼운 3D + 투명도
      alignment = isNextPage ? Alignment.centerRight : Alignment.centerLeft;
      matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0008)
        ..rotateY(pageOffset * -0.28)
        ..translate(vec.Vector3(pageOffset * -14.0, 0.0, 0.0));

      opacity = (1.0 - absOffset * 0.30).clamp(0.0, 1.0);
    }

    // 단일 위젯 트리 공유: 구조 자체(Stack vs Opacity)가 다르면 
    // 전환 완료 시점에 Flutter가 리마운트하면서 반짝거림(flash)이 발생합니다.
    // 이를 막기 위해 항상 동일한 트리를 반환하고 수치만 변경합니다.
    Widget content = Transform.scale(
      scale: scale,
      child: Transform(
        transform: matrix,
        alignment: alignment,
        child: Opacity(
          // shouldHide 상태면 즉시 0.0 (AnimatedOpacity의 지연 여운 제거)
          opacity: shouldHide ? 0.0 : opacity,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: shadowBegin,
                        end: shadowEnd,
                        colors: [
                          Colors.black.withValues(alpha: shadowAlpha),
                          Colors.black.withValues(alpha: shadowAlpha * 0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.25, 0.70],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // AnimatedOpacity 지연(120ms) 때문에 생기는 잔상/늦게 나타남 방지.
    // 수치 기반으로 즉각 처리
    return IgnorePointer(
      ignoring: shouldHide,
      child: content,
    );
  }
}

// ── 페이지 넘김 물리 ──────────────────────────────────────────────
/// 짝수 경계(책 넘기기)에서는 좀 더 묵직한 감도, 슬라이드는 가볍게
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
