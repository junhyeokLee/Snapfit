import 'package:flutter/material.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import 'intro_artwork_cache.dart';

/// Fixed artwork for P1–3 only. The print typography is baked into three small
/// assets, so opening the introduction does not load another runtime font.
class IntroCoverArtwork extends StatelessWidget {
  const IntroCoverArtwork({super.key, required this.chapter});
  final int chapter;

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: switch (chapter) {
      1 => const _Designs(),
      2 => const _Editor(),
      _ => const _Memories(),
    },
  );
}

const _paper = Color(0xFFF7F5F2);
const _parentPhoto =
    'assets/templates/soft_babybook/images/approved_stock/parent_back.jpg';

class _Cover extends StatelessWidget {
  const _Cover(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 5 / 7,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 14,
            offset: const Offset(3, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
        child: _IntroAssetImage(
          asset: 'assets/onboarding/intro_$name.png',
          decodeWidth: name == 'travel' ? 384 : 256,
        ),
      ),
    ),
  );
}

class _Memories extends StatelessWidget {
  const _Memories();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned(
        left: 24,
        top: 118,
        child: _LoosePhoto(
          asset: 'assets/frame_preview/spring_flowers.jpg',
          decodeWidth: 224,
          angle: -.262,
        ),
      ),
      const Positioned(
        right: 17,
        top: 141,
        child: _LoosePhoto(asset: _parentPhoto, decodeWidth: 192, angle: .175),
      ),
      Positioned(
        left: 105,
        top: 19,
        width: 160,
        child: Transform.rotate(angle: -.105, child: const _Cover('travel')),
      ),
    ],
  );
}

class _LoosePhoto extends StatelessWidget {
  const _LoosePhoto({
    required this.asset,
    required this.decodeWidth,
    required this.angle,
  });
  final String asset;
  final int decodeWidth;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 99,
      height: 124,
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 18),
      decoration: BoxDecoration(
        color: _paper,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 9,
            offset: const Offset(2, 6),
          ),
        ],
      ),
      child: _IntroAssetImage(asset: asset, decodeWidth: decodeWidth),
    ),
  );
}

class _Designs extends StatelessWidget {
  const _Designs();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (final (name, x, y, angle, width) in [
        ('family', 17.0, 80.0, -.192, 116.0),
        ('daily', 207.0, 93.0, .175, 116.0),
        ('travel', 99.0, 22.0, -.052, 146.0),
      ])
        Positioned(
          left: x,
          top: y,
          width: width,
          child: Transform.rotate(angle: angle, child: _Cover(name)),
        ),
      Positioned(
        bottom: 6,
        left: 0,
        right: 0,
        child: Text(
          '여행    ·    가족    ·    일상',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: .5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

class _Editor extends StatelessWidget {
  const _Editor();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 244,
      height: 288,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.arrow_back, size: 13),
              Text('표지', style: TextStyle(fontSize: 10)),
              Text('저장', style: TextStyle(fontSize: 10)),
            ],
          ),
          SizedBox(
            width: 112,
            height: 156.8,
            child: Stack(
              children: [
                const _Cover('daily'),
                Positioned(
                  left: 10.08,
                  right: 8.96,
                  top: 28.224,
                  height: 62.72,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: SnapFitColors.accent),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final alignment in [
                          Alignment.topLeft,
                          Alignment.topRight,
                          Alignment.bottomLeft,
                          Alignment.bottomRight,
                        ])
                          Align(
                            alignment: alignment,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _paper,
                                shape: BoxShape.circle,
                                border: Border.all(color: SnapFitColors.accent),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              for (final (icon, label) in [
                (Icons.add_photo_alternate_outlined, '사진'),
                (Icons.crop, '자르기'),
                (Icons.palette_outlined, '꾸미기'),
                (Icons.layers_outlined, '재배치'),
              ])
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// A page registers its bounded decode keys with the intro-wide cache. Standalone
/// artwork falls back to a local lease, without changing home or reader images.
class _IntroAssetImage extends StatefulWidget {
  const _IntroAssetImage({required this.asset, required this.decodeWidth});
  final String asset;
  final int decodeWidth;

  @override
  State<_IntroAssetImage> createState() => _IntroAssetImageState();
}

class _IntroAssetImageState extends State<_IntroAssetImage> {
  late ResizeImage _provider;
  IntroArtworkCacheSession? _fallback;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  void _configure() {
    _provider = ResizeImage(
      AssetImage(widget.asset),
      width: widget.decodeWidth,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rememberKey();
  }

  @override
  void didUpdateWidget(covariant _IntroAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset ||
        oldWidget.decodeWidth != widget.decodeWidth) {
      _configure();
      _rememberKey();
    }
  }

  void _rememberKey() {
    final session = IntroArtworkCache.maybeOf(context);
    if (session != null) {
      _fallback?.dispose();
      _fallback = null;
    }
    (session ?? (_fallback ??= IntroArtworkCacheSession())).remember(
      _provider,
      createLocalImageConfiguration(context),
    );
  }

  @override
  void dispose() {
    _fallback?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: _provider,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, _, _) => const ColoredBox(color: _paper),
  );
}
