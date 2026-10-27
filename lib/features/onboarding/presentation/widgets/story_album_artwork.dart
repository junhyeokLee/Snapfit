import 'package:flutter/material.dart';

import 'intro_cover_artwork.dart';

/// Small static compositions; no catalog parsing, network images, or tickers.
class StoryAlbumArtwork extends StatelessWidget {
  const StoryAlbumArtwork({super.key, required this.chapter});
  final int chapter;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 340,
          height: 320,
          child: switch (chapter) {
            0 || 1 || 2 => IntroCoverArtwork(chapter: chapter),
            _ => const _Reader(),
          },
        ),
      ),
    ),
  );
}

const _photos = [
  'assets/frame_preview/ocean_shore.jpg',
  'assets/frame_preview/spring_flowers.jpg',
  'assets/frame_preview/alpine_lake.jpg',
];

class _Photo extends StatelessWidget {
  const _Photo(this.index);
  final int index;

  @override
  Widget build(BuildContext context) => Image.asset(
    _photos[index],
    fit: BoxFit.cover,
    // All scenes share the same three bounded decode keys.
    cacheWidth: 512,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFD9DFD3)),
  );
}

class StoryAlbumCover extends StatelessWidget {
  const StoryAlbumCover({super.key, this.edition = 0})
    : assert(edition >= 0 && edition <= 2);
  final int edition;

  @override
  Widget build(BuildContext context) {
    final dark = edition == 2;
    final ink = dark ? const Color(0xFFF4EAD5) : const Color(0xFF3D4D41);
    final paper = switch (edition) {
      1 => const Color(0xFFEBD8CD),
      2 => const Color(0xFF2E4A40),
      _ => const Color(0xFFF3EFE4),
    };
    final title = switch (edition) {
      1 => '우리의\n모든 계절',
      2 => '작고 다정한\n순간들',
      _ => '여름이\n머문 자리',
    };
    return AspectRatio(
      aspectRatio: 200 / 280,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 14,
              offset: const Offset(3, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(5),
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            child: MediaQuery.withNoTextScaling(
              child: SizedBox(
                width: 200,
                height: 280,
                child: ColoredBox(
                  color: paper,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 24,
                        top: 23,
                        child: Text(
                          [
                            'SUMMER ARCHIVE',
                            'IN GOOD COMPANY',
                            'A LITTLE JOURNAL',
                          ][edition],
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: ink,
                            fontSize: 7,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 20,
                        top: 51,
                        height: 129,
                        child: _Photo(edition),
                      ),
                      Positioned(
                        left: 24,
                        top: 195,
                        right: 16,
                        child: Text(
                          title,
                          style: TextStyle(
                            color: ink,
                            fontFamily: 'NotoSans',
                            fontSize: 22,
                            height: 1.25,
                            letterSpacing: -.6,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        bottom: 13,
                        child: Text(
                          'OUR DAYS, ON PAPER',
                          style: TextStyle(
                            color: ink,
                            fontSize: 6,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: .15),
                                  Colors.white.withValues(alpha: .23),
                                  Colors.transparent,
                                ],
                                stops: const [0, .025, .065],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Reader extends StatelessWidget {
  const _Reader();

  @override
  Widget build(BuildContext context) => Center(
    child: Transform.rotate(
      angle: -.035,
      child: SizedBox(
        height: 220,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: MediaQuery.withNoTextScaling(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '우리가 함께한 여름',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 12,
                            color: Color(0xFF3D4D41),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Expanded(
                          child: SizedBox.expand(child: _Photo(0)),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, color: const Color(0xFFDAD4C5)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: SizedBox.expand(child: _Photo(2)),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '다시, 이 계절에.',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 12,
                            color: Color(0xFF3D4D41),
                          ),
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
    ),
  );
}
