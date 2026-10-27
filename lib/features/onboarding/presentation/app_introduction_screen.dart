import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import 'first_visit_controller.dart';
import 'widgets/intro_artwork_cache.dart';
import 'widgets/story_album_artwork.dart';

class AppIntroductionScreen extends ConsumerStatefulWidget {
  const AppIntroductionScreen({
    super.key,
    this.firstVisit = false,
    this.onFinished,
  });

  final bool firstVisit;
  final VoidCallback? onFinished;

  @override
  ConsumerState<AppIntroductionScreen> createState() =>
      _AppIntroductionScreenState();
}

class _AppIntroductionScreenState extends ConsumerState<AppIntroductionScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _moving = false, _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish({bool skipped = false}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    if (widget.firstVisit) {
      await ref
          .read(firstVisitProvider.notifier)
          .completeIntroduction(skipped: skipped);
    }
    if (!mounted) return;
    if (widget.onFinished case final onFinished?) {
      onFinished();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _goTo(int index) async {
    if (_moving || _finishing || !_pages.hasClients) return;
    _moving = true;
    try {
      if (SnapFitMotion.reduced(context)) {
        _pages.jumpToPage(index);
      } else {
        await _pages.animateToPage(
          index,
          duration: SnapFitMotion.medium,
          curve: SnapFitMotion.entrance,
        );
      }
    } finally {
      _moving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final brand = dark ? SnapFitColors.accentInkDark : SnapFitColors.accentInk;
    return PopScope(
      canPop: !widget.firstVisit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.firstVisit) _finish(skipped: true);
      },
      child: IntroArtworkCache(
        child: Scaffold(
          key: const ValueKey('app-introduction'),
          backgroundColor: dark
              ? const Color(0xFF1C2420)
              : const Color(0xFFF5F8F6),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'snapfit',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.1,
                              color: brand,
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('intro-skip'),
                            onPressed: _finishing
                                ? null
                                : () => _finish(skipped: true),
                            style: TextButton.styleFrom(
                              foregroundColor: ExperienceFormStyle.muted(
                                context,
                              ),
                              minimumSize: const Size(44, 44),
                            ),
                            child: Text(widget.firstVisit ? '건너뛰기' : '닫기'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        key: const ValueKey('intro-pages'),
                        controller: _pages,
                        itemCount: _chapters.length,
                        allowImplicitScrolling: false,
                        onPageChanged: (index) =>
                            setState(() => _index = index),
                        itemBuilder: (_, index) =>
                            _IntroductionPage(index: index, brand: brand),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (
                                var index = 0;
                                index < _chapters.length;
                                index++
                              )
                                Semantics(
                                  selected: _index == index,
                                  child: IconButton(
                                    key: ValueKey('intro-page-$index'),
                                    tooltip:
                                        '소개 ${index + 1} / ${_chapters.length}',
                                    onPressed: _finishing
                                        ? null
                                        : () => _goTo(index),
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    icon: AnimatedContainer(
                                      duration: SnapFitMotion.duration(
                                        context,
                                        SnapFitMotion.fast,
                                      ),
                                      width: _index == index ? 20 : 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: _index == index
                                            ? brand
                                            : ExperienceFormStyle.line(context),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              if (_index != 0) ...[
                                IconButton(
                                  key: const ValueKey('intro-previous'),
                                  tooltip: '이전 소개',
                                  onPressed: _finishing
                                      ? null
                                      : () => _goTo(_index - 1),
                                  icon: const Icon(Icons.arrow_back, size: 21),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: FilledButton(
                                  key: const ValueKey('intro-next'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: SnapFitColors.actionAccent,
                                    foregroundColor: SnapFitColors.onAccent,
                                    minimumSize: const Size(0, 52),
                                    textStyle: ExperienceFormStyle.text(
                                      context,
                                      14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: _finishing
                                      ? null
                                      : () => _index == 3
                                            ? _finish()
                                            : _goTo(_index + 1),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _index == 3
                                              ? widget.firstVisit
                                                    ? '시작하기'
                                                    : '소개 마치기'
                                              : '다음',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _chapters = [
  (
    eyebrow: 'YOUR MOMENTS, YOUR BOOK',
    title: '사진이,\n한 권의 기억으로.',
    description: '흩어져 있던 소중한 순간을\n나만의 앨범으로 간직해요.',
  ),
  (
    eyebrow: 'FIND YOUR DESIGN',
    title: '마음에 드는\n디자인부터 골라요.',
    description: '표지부터 내지까지 둘러보고\n우리의 이야기에 어울리는 디자인을 찾아요.',
  ),
  (
    eyebrow: 'MAKE IT YOURS',
    title: '내 사진을 채우고,\n취향대로 다듬어요.',
    description: '사진과 글을 더하고, 재배치하며\n나만의 한 페이지를 만들어요.',
  ),
  (
    eyebrow: 'ALWAYS CLOSE TO YOU',
    title: '언제든 펼쳐보고,\n이어서 만들어가요.',
    description: '완성한 앨범은 책처럼 감상하고\n만들던 앨범은 저장한 곳에서 이어가요.',
  ),
];

class _IntroductionPage extends StatelessWidget {
  const _IntroductionPage({required this.index, required this.brand});
  final int index;
  final Color brand;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 600;
      final chapter = _chapters[index];
      final copy = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapter.eyebrow,
            style: ExperienceFormStyle.text(
              context,
              11,
              color: brand,
            ).copyWith(letterSpacing: 1.1),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              chapter.title,
              style: ExperienceFormStyle.text(
                context,
                28,
                weight: FontWeight.w600,
              ).copyWith(height: 1.42, letterSpacing: -1),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            chapter.description,
            style: ExperienceFormStyle.text(
              context,
              14,
              secondary: true,
            ).copyWith(height: 1.7),
          ),
        ],
      );
      final art = StoryAlbumArtwork(chapter: index);
      return SingleChildScrollView(
        key: ValueKey('intro-content-$index'),
        primary: false,
        padding: const EdgeInsets.fromLTRB(26, 12, 26, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, bounds.maxHeight - 30),
          ),
          child: wide
              ? Row(
                  children: [
                    SizedBox(
                      width: bounds.maxWidth * .43,
                      height: math.min(300, bounds.maxHeight),
                      child: art,
                    ),
                    const SizedBox(width: 28),
                    Expanded(child: copy),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: (bounds.maxHeight * .53).clamp(125.0, 320.0),
                      child: art,
                    ),
                    const SizedBox(height: 14),
                    copy,
                  ],
                ),
        ),
      );
    },
  );
}
