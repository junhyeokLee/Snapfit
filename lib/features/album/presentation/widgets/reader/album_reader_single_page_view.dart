import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album_page.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../cover/cover.dart';
import 'book_page_view.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앨범 리더 단일 페이지 뷰
///
/// PageView에서 한 장씩 표시하되:
///   - 같은 쌍(1-2, 3-4, 5-6) 내에서는 서로 살짝 peek 허용
///   - 쌍 경계(2→3, 4→5)는 3D 책 넘기기로 전환
///   - 쌍이 다른 페이지는 완전히 숨겨 겹침 방지
class AlbumReaderSinglePageView extends ConsumerStatefulWidget {
  /// 모든 페이지 (0 = 커버, 1~ = 내지)
  final List<AlbumPage> allPages;
  final CoverSize selectedCover;
  final CoverTheme coverTheme;
  final PageController pageController;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final GlobalKey canvasKey;
  final ValueChanged<Size> onCanvasSizeChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onStateChanged;

  const AlbumReaderSinglePageView({
    super.key,
    required this.allPages,
    required this.selectedCover,
    required this.coverTheme,
    required this.pageController,
    required this.interaction,
    required this.layerBuilder,
    required this.canvasKey,
    required this.onCanvasSizeChanged,
    required this.onPageChanged,
    required this.onStateChanged,
  });

  @override
  ConsumerState<AlbumReaderSinglePageView> createState() => _AlbumReaderSinglePageViewState();
}

class _AlbumReaderSinglePageViewState extends ConsumerState<AlbumReaderSinglePageView> {
  bool _isCoverPressed = false;

  void onStateChanged() {
    if (mounted) widget.onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;

    // 표시 가능한 최대 너비 (여백 포함)
    final availW = screenW - 40.w;

    // 단일 페이지 기준 허용 최대 크기
    // 스프레드일 때 화면 너비(availW) 안에 2장과 가운데 제본선(4.w)이 딱 맞아야 함
    final double maxSingleW = (availW - 4.w) / 2;
    final double maxH = screenH * 0.62;

    // 단일 페이지 비율
    final coverRatio = widget.selectedCover.ratio;

    final double singlePageW;
    final double singlePageH;

    final hFromW = maxSingleW / coverRatio;
    if (hFromW <= maxH) {
      singlePageW = maxSingleW;
      singlePageH = hFromW;
    } else {
      singlePageH = maxH;
      singlePageW = maxH * coverRatio;
    }

    // 아이템 수 계산: 커버(1) + 내지 쌍 개수
    final int innerPageCount = math.max(0, widget.allPages.length - 1);
    final int spreadCount = (innerPageCount / 2).ceil();
    final int itemCount = 1 + spreadCount;

    // 0 미만 바운스 방지
    final safePage = (widget.pageController.hasClients ? (widget.pageController.page ?? 0.0) : 0.0).clamp(0.0, (itemCount - 1).toDouble());

    // 터치 이벤트를 뷰 외곽에 감싸는 PageView 레이어
    final pageView = BookPageView(
      pageController: widget.pageController,
      itemCount: itemCount,
      onPageChanged: (index) {
        widget.onPageChanged(index);
        onStateChanged();
      },
      // PageView는 더 이상 화면 렌더링에 관여하지 않고 터치 제스처와 스크롤 상태만 제공
      itemBuilder: (context, index, offset) {
        return const SizedBox.shrink(); // 터치 인식용 투명 컨테이너
      },
    );

    return Stack(
      children: [
        // 1. 실제 화면 렌더링 레이어 (터치 비활성)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: widget.pageController,
              builder: (context, child) {
                final double page = widget.pageController.hasClients ? (widget.pageController.page ?? 0.0) : 0.0;
                
                // 0 -> 1 전환 구간(커버 펼침) 및 상시 바닥 그림자 처리
                // GPU 스케일 텍스처 재생성 깜박임 방지용 상시 가속 유도 (1.0 -> 0.9999)
                double currentScale = 0.9999;
                double shadowAlpha = 0.15; // 평상시 바닥 기본 그림자 농도를 대폭 상향
                double shadowBlur = 50.0;
                double shadowSpread = 5.0;

                if (page >= 0.0 && page < 1.0) {
                  // page 값이 진행되는 동안 (0.0 ~ 1.0), sin 곡선(0.0 -> 1.0 -> 0.0)을 그림
                  final bounceRatio = math.sin(page * math.pi);
                  currentScale = 0.9999 - (bounceRatio * 0.12); // 최대 88% 로 작아짐 (0.8799). 1.0 으로 리셋 시 텍스처 파괴(Flicker) 발생 방지
                  shadowAlpha = 0.15 + (bounceRatio * 0.1); // 공중 바운스 시 진해짐(0.25)
                  shadowBlur = 50.0 + (bounceRatio * 50.0); // 더 넓게 퍼짐(100.0)
                  shadowSpread = 5.0 + (bounceRatio * 20.0); // 밖으로 크게 번짐
                }

                // 탭다운(누름)에 의한 수동 스케일은 커버가 가만히 있을 때만(0.0) 적용
                if (page == 0.0 && _isCoverPressed) {
                  currentScale = 0.95;
                  shadowAlpha = 0.20;
                  shadowBlur = 30.0;
                  shadowSpread = -5.0;
                }

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // 앨범 하단에 상시 깔리는 통짜 그림자 (입체감 부여)
                    if (shadowAlpha > 0.01)
                      Container(
                        width: singlePageW * 2, // 펼쳤을 때의 전체 너비
                        height: singlePageH,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: shadowAlpha),
                              blurRadius: shadowBlur,
                              spreadRadius: shadowSpread,
                              offset: Offset(0, shadowBlur / 2),
                            )
                          ],
                        ),
                      ),

                    // 책 자체는 스케일 트랜스폼 처리 (Tween 래퍼를 걷어내어 재빌드 반짝임 원천 차단)
                    Transform.scale(
                      scale: currentScale,
                      child: Center(
                        child: _GlobalPageFlipRenderer(
                          page: page,
                          itemCount: itemCount,
                          singleW: singlePageW,
                          doubleH: singlePageH,
                          allPages: widget.allPages,
                          selectedCover: widget.selectedCover,
                          coverTheme: widget.coverTheme,
                          interaction: widget.interaction,
                          layerBuilder: widget.layerBuilder,
                          canvasKey: widget.canvasKey,
                          onCanvasSizeChanged: widget.onCanvasSizeChanged,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // 2. 터치 제스처 레이어 (PageView)
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (_) {
              if (safePage < 0.5) {
                setState(() => _isCoverPressed = true);
              }
            },
            onTapUp: (_) {
              if (_isCoverPressed) {
                setState(() => _isCoverPressed = false);
              }
            },
            onTapCancel: () {
              if (_isCoverPressed) {
                setState(() => _isCoverPressed = false);
              }
            },
            onTap: () {
              if (widget.interaction.selectedLayerId != null) {
                widget.interaction.clearSelection();
                onStateChanged();
              } else if (safePage < 0.5) {
                // 커버가 절반 넘게 닫혀있으면 무조건 1페이지로 바운스하며 확 열어버림!
                widget.pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 1200), // 시네마틱 속도
                  curve: Curves.easeInOutCubic,
                );
              }
            },
            behavior: HitTestBehavior.translucent,
            child: pageView,
          ),
        ),
      ],
    );
  }
}

// ── 단일 렌더러 기반 플립 애니메이션 ───────────────────────────────
class _GlobalPageFlipRenderer extends StatelessWidget {
  final double page;
  final int itemCount;
  final double singleW;
  final double doubleH;
  final List<AlbumPage> allPages;
  final dynamic selectedCover; // 타입 생략, 넘어오는 그대로 사용
  final dynamic coverTheme;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final GlobalKey canvasKey;
  final Function(Size) onCanvasSizeChanged;

  const _GlobalPageFlipRenderer({
    required this.page,
    required this.itemCount,
    required this.singleW,
    required this.doubleH,
    required this.allPages,
    required this.selectedCover,
    required this.coverTheme,
    required this.interaction,
    required this.layerBuilder,
    required this.canvasKey,
    required this.onCanvasSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 0 미만 바운스, itemCount 이상 바운스 처리
    final double safePage = page.clamp(0.0, (itemCount - 1).toDouble());
    final int currentIndex = safePage.floor();
    final int nextIndex = currentIndex + 1;
    final double fraction = safePage - currentIndex; // 0.0 ~ 1.0

    // --- 스와이프 도중 및 정지(0.0) 상태의 3D 렌더링 통합 (위젯 트리 교체로 인한 반짝임 방지) ---
    // GPU 텍스처 가속 무효화 버스트(Flickering) 방지 핵심 트릭:
    // angle이 완벽한 0.0이면 플러터가 2D 모드로 렌더를 최적화하다가 0.01 회전 시 3D 텍스처로 강제 재파싱하며 이미지가 번쩍거립니다.
    // 이를 막기 위해 어떠한 경우에도 아주 미세한 기본 회전값을 유지해 GPU 뎁스버퍼를 항상 살려둡니다.
    double angle = fraction * math.pi;
    if (angle == 0.0) {
      angle = 0.00005; // 육안으로 절대 보이지 않는 3D 강제 활성 기울기
    }
    
    // Layer 0: 바닥 배경
    Widget layer0Background;
    if (currentIndex == 0) {
      // 커버가 열릴 때: 바닥 우측(2페이지)만 깔아두어 커버가 왼쪽으로 넘어가면서 자연스럽게 2페이지가 노출됨.
      layer0Background = Center(
        child: _buildInnerSpreadHalf(nextIndex, isLeft: false),
      );
      
      // 커버가 닫혀갈 때(fraction -> 0) 2페이지가 우측에서 제자리 소멸하면 부자연스러우므로, 
      // 완전히 덮이는 시점(fraction=0)에 화면 중앙(Center)으로 스르륵 따라 오도록 슬라이드 시킴
      final double slideOffset = -(singleW / 2) * (1.0 - fraction);
      layer0Background = Transform.translate(
        offset: Offset(slideOffset, 0),
        child: layer0Background,
      );
      
      // 커버가 완전히 덮이기 직전(0.2 ~ 0.0 구간)에 서서히 페이드아웃 시키되,
      // 투명도 0.0 으로 완전히 소멸시키면 플러터 렌더 최적화가 발동되어 다음 스와이프 시작 시 첫 프레임에 로딩 버스트(Jank/깜박임)가 터지므로,
      // 육안에 안 보이는 1% (0.01) 투명도를 유지해 백그라운드에 텍스처를 미리 살려둡니다.
      layer0Background = Opacity(
        opacity: (0.01 + fraction * 5).clamp(0.01, 1.0),
        child: layer0Background,
      );
    } else {
      // 핵심 해결: 내지 넘길 때 바닥에 다음 스프레드 '전체'를 통짜로 깔아버리면, 
      // 넘어간 뒤 해당 영역이 '절반' 레이아웃으로 교체되는 순간 부모 트리 구조가 달라져(Layout Shift) 화면 전체가 번쩍임!
      // 따라서 어차피 왼쪽은 layer1Left가 덮고 있으므로 바닥엔 항상 오른쪽 '절반'만 그리도록 통일시킵니다.
      layer0Background = Center(
        child: nextIndex == 0 ? _buildCoverCard() : _buildInnerSpreadHalf(nextIndex, isLeft: false),
      );
    }

    // Layer 1: A의 왼쪽 바닥 부분
    Widget layer1Left = const SizedBox.shrink();
    if (currentIndex > 0) {
      layer1Left = Center(
        child: _buildInnerSpreadHalf(currentIndex, isLeft: true),
      );
    }

    // Layer 2: A의 들리는 오른쪽 판
    Widget layer2Right = const SizedBox.shrink();
    if (fraction < 0.5) {
      final angle = fraction * math.pi;
      if (currentIndex == 0) {
        layer2Right = Center(
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: _buildCoverCard(),
          ),
        );
      } else {
        layer2Right = Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: _buildInnerSpreadHalf(currentIndex, isLeft: false),
          ),
        );
      }
    }

    // Layer 3: B의 거울상 뒷면 강하
    Widget layer3Left = const SizedBox.shrink();
    if (fraction >= 0.5 && nextIndex < itemCount) {
      final angle = (1.0 - fraction) * math.pi;
      if (nextIndex == 0) {
        layer3Left = Center(
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(-angle),
            child: _buildCoverCard(),
          ),
        );
      } else {
        layer3Left = Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(-angle),
            child: _buildInnerSpreadHalf(nextIndex, isLeft: true),
          ),
        );
      }
    }

    return Stack(
      children: [
        layer0Background,
        layer1Left,
        layer2Right,
        layer3Left,
      ],
    );
  }

  // 입체적인 제본선(책등) 그라데이션
  Widget _buildSpine() {
    return Container(
      width: 2.w,
      height: doubleH * 0.98, // 카드 위아래 여백을 고려하여 아주 살짝 짧게
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 1.0,
            spreadRadius: 0.5,
          )
        ],
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.05),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }


  // 절반만 렌더링 (나머지는 투명 사이즈박스로 축 위치 보존)
  Widget _buildInnerSpreadHalf(int index, {required bool isLeft}) {
    if (index >= itemCount || index == 0) return const SizedBox.shrink();

    final leftIndex = 1 + (index - 1) * 2;
    final rightIndex = leftIndex + 1;
    final lPage = leftIndex < allPages.length ? allPages[leftIndex] : null;
    final rPage = rightIndex < allPages.length ? allPages[rightIndex] : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        isLeft 
          ? SizedBox(
              width: singleW, 
              height: doubleH, 
              child: lPage != null ? _buildInnerCard(lPage) : Container(color: SnapFitColors.pureWhite),
            )
          : SizedBox(width: singleW),
        
        isLeft ? _buildSpine() : SizedBox(width: 2.w), // 2.w 맞춤

        !isLeft 
          ? SizedBox(
              width: singleW, 
              height: doubleH, 
              child: rPage != null ? _buildInnerCard(rPage) : Container(color: SnapFitColors.pureWhite),
            )
          : SizedBox(width: singleW),
      ],
    );
  }

  Widget _buildCoverCard() {
    return _CoverPageCard(
      key: GlobalObjectKey(allPages.isNotEmpty ? allPages[0] : 'cover'),
      page: allPages[0],
      pageW: singleW,
      pageH: doubleH,
      selectedCover: selectedCover,
      coverTheme: coverTheme,
      interaction: interaction,
      layerBuilder: layerBuilder,
      coverKey: canvasKey,
      onCoverSizeChanged: onCanvasSizeChanged,
    );
  }

  Widget _buildInnerCard(AlbumPage page) {
    return _InnerPageCard(
      key: ValueKey('inner_page_${page.id}'),
      page: page,
      pageW: singleW,
      pageH: doubleH,
      interaction: interaction,
      layerBuilder: layerBuilder,
    );
  }
}

class _CoverPageCard extends StatelessWidget {
  final AlbumPage page;
  final double pageW;
  final double pageH;
  final CoverSize selectedCover;
  final CoverTheme coverTheme;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final GlobalKey coverKey;
  final ValueChanged<Size> onCoverSizeChanged;

  const _CoverPageCard({
    super.key,
    required this.page,
    required this.pageW,
    required this.pageH,
    required this.selectedCover,
    required this.coverTheme,
    required this.interaction,
    required this.layerBuilder,
    required this.coverKey,
    required this.onCoverSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // [10단계 Fix] 리더 화면의 커버도 500xH 논리 고정 좌표계를 사용하여 렌더링합니다.
    final double aspect = selectedCover.ratio > 0 ? selectedCover.ratio : 1.0;
    const double logicalW = kCoverReferenceWidth; // 500.0
    final double logicalH = logicalW / aspect;
    
    // 실제 화면 대비 스케일 계산
    final double scale = pageW / logicalW;

    return Container(
      width: pageW,
      height: pageH,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: 2,
          ),
        ],
      ),
      child: RepaintBoundary(
        key: coverKey,
        child: OverflowBox(
          // 논리 사이즈로 강제 렌더링 후 스케일링
          minWidth: logicalW,
          maxWidth: logicalW,
          minHeight: logicalH,
          maxHeight: logicalH,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            child: CoverLayout(
              aspect: aspect,
              layers: interaction.sortByZ(page.layers),
              isInteracting: false,
              leftSpine: 14.0,
              onCoverSizeChanged: onCoverSizeChanged,
              buildImage: (layer) => layerBuilder.buildImage(layer, isCover: true),
              buildText: (layer) => layerBuilder.buildText(layer, isCover: true),
              sortedByZ: interaction.sortByZ,
              theme: coverTheme,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 내지 페이지 카드 ──────────────────────────────────────────────
class _InnerPageCard extends StatelessWidget {

  final AlbumPage page;
  final double pageW;
  final double pageH;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;

  const _InnerPageCard({
    super.key,
    required this.page,
    required this.pageW,
    required this.pageH,
    required this.interaction,
    required this.layerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // [Inner Page Fix] 에디터와 동일하게 커버 비율을 반영한 논리적 베이스 사이즈 계산
    final ratio = pageW / pageH;
    final logicalW = 300.0;
    final logicalH = 300.0 / ratio;
    final logicalBaseSize = Size(logicalW, logicalH);

    final scale = pageW / logicalW;

    return ClipRect(
      child: Container(
        width: pageW,
        height: pageH,
        color: SnapFitColors.pureWhite,
        child: Stack(
          clipBehavior: Clip.none, // 페이지 밖으로 살짝 나가는 요소(그림자 등) 허용
          children: [
            Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: logicalBaseSize.width,
                height: logicalBaseSize.height,
                child: Stack(
                  clipBehavior: Clip.none, // 회전된 레이어의 모서리가 잘리는 현상 방지
                  children: interaction.sortByZ(page.layers).map((layer) {
                    if (layer.type == LayerType.image) {
                      return layerBuilder.buildImage(layer);
                    }
                    return layerBuilder.buildText(layer);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
