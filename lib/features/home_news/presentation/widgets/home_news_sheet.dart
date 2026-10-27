import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/home_news.dart';

/// A single home story. The caller records exposure and handles the destination.
Future<bool?> showHomeNewsSheet(
  BuildContext context,
  HomeNewsItem item, {
  Widget Function(Widget child)? contentWrapper,
}) => _showHomeNewsModal<bool>(
  context,
  contentWrapper: contentWrapper,
  builder: (sheetContext, desktop) => HomeNewsSheetContent(
    item: item,
    desktop: desktop,
    onAction: () => Navigator.of(sheetContext).pop(true),
    onClose: () => Navigator.of(sheetContext).pop(false),
  ),
);

class HomeNewsSheetResult {
  const HomeNewsSheetResult({required this.item, required this.action});

  final HomeNewsItem item;
  final bool action;
}

Future<HomeNewsSheetResult?> showHomeNewsCarousel(
  BuildContext context,
  List<HomeNewsItem> items, {
  int initialIndex = 0,
  ValueChanged<HomeNewsItem>? onItemViewed,
  Widget Function(Widget child)? contentWrapper,
}) {
  if (items.isEmpty) return Future.value();
  final snapshot = List<HomeNewsItem>.unmodifiable(items);
  return _showHomeNewsModal<HomeNewsSheetResult>(
    context,
    contentWrapper: contentWrapper,
    builder: (sheetContext, desktop) => HomeNewsCarouselContent(
      items: snapshot,
      initialIndex: initialIndex,
      desktop: desktop,
      onItemViewed: onItemViewed,
      onAction: (item) => Navigator.of(
        sheetContext,
      ).pop(HomeNewsSheetResult(item: item, action: true)),
      onClose: (item) => Navigator.of(
        sheetContext,
      ).pop(HomeNewsSheetResult(item: item, action: false)),
    ),
  );
}

Future<T?> _showHomeNewsModal<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, bool desktop) builder,
  Widget Function(Widget child)? contentWrapper,
}) {
  final media = MediaQuery.of(context);
  final desktop = media.size.width >= 760;
  final motion = SnapFitMotion.reduced(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(
          duration: SnapFitMotion.medium,
          reverseDuration: SnapFitMotion.fast,
        );
  Widget content(BuildContext sheetContext) {
    final child = builder(sheetContext, desktop);
    return contentWrapper?.call(child) ?? child;
  }

  if (desktop) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: .40),
      animationStyle: motion,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 480),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: content(dialogContext),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: .34),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    sheetAnimationStyle: motion,
    constraints: const BoxConstraints(maxWidth: 600),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: content,
  );
}

/// One modal can contain all available stories; only the settled page can act.
class HomeNewsCarouselContent extends StatefulWidget {
  const HomeNewsCarouselContent({
    super.key,
    required this.items,
    required this.onAction,
    required this.onClose,
    this.initialIndex = 0,
    this.onItemViewed,
    this.desktop = false,
  }) : assert(items.length > 0);

  final List<HomeNewsItem> items;
  final int initialIndex;
  final ValueChanged<HomeNewsItem> onAction;
  final ValueChanged<HomeNewsItem> onClose;
  final ValueChanged<HomeNewsItem>? onItemViewed;
  final bool desktop;

  @override
  State<HomeNewsCarouselContent> createState() =>
      _HomeNewsCarouselContentState();
}

class _HomeNewsCarouselContentState extends State<HomeNewsCarouselContent> {
  late final PageController _pages;
  late int _index;
  String? _lastViewedId;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pages = PageController(initialPage: _index);
    _reportViewed();
  }

  void _reportViewed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final item = widget.items[_index];
      if (_lastViewedId == item.id) return;
      _lastViewedId = item.id;
      widget.onItemViewed?.call(item);
    });
  }

  @override
  void didUpdateWidget(covariant HomeNewsCarouselContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous =
        oldWidget.items[_index.clamp(0, oldWidget.items.length - 1)];
    final retained = widget.items.indexWhere((item) => item.id == previous.id);
    final next = retained < 0
        ? _index.clamp(0, widget.items.length - 1)
        : retained;
    if (next != _index) {
      _index = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_index);
      });
    }
    _reportViewed();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (!_pages.hasClients ||
        _finishing ||
        index < 0 ||
        index >= widget.items.length ||
        index == _index) {
      return;
    }
    if (SnapFitMotion.reduced(context)) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: SnapFitMotion.medium,
        curve: SnapFitMotion.entrance,
      );
    }
  }

  void _finish(bool action, {int? index}) {
    if (_finishing || (index != null && index != _index)) return;
    _finishing = true;
    final item = widget.items[_index];
    if (action) {
      widget.onAction(item);
    } else {
      widget.onClose(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.length == 1) {
      final item = widget.items.single;
      return HomeNewsSheetContent(
        item: item,
        desktop: widget.desktop,
        onAction: () => _finish(true),
        onClose: () => _finish(false),
      );
    }
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.padding.top - (widget.desktop ? 48 : 16);
    final height = math.min(widget.desktop ? 600.0 : 584.0, available);
    return SizedBox(
      key: const ValueKey('home-news-carousel'),
      height: math.max(120.0, height),
      child: Semantics(
        onIncrease: _index < widget.items.length - 1
            ? () => _goTo(_index + 1)
            : null,
        onDecrease: _index > 0 ? () => _goTo(_index - 1) : null,
        child: PageView.builder(
          key: const ValueKey('home-news-pages'),
          controller: _pages,
          itemCount: widget.items.length,
          onPageChanged: (index) {
            setState(() => _index = index);
            _reportViewed();
          },
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return HomeNewsSheetContent(
              key: ValueKey(item.id),
              item: item,
              desktop: widget.desktop,
              pageControls: _pageControls(context),
              onAction: () => _finish(true, index: index),
              onClose: () => _finish(false),
            );
          },
        ),
      ),
    );
  }

  Widget _pageControls(BuildContext context) {
    final ink = ExperienceFormStyle.selectionInk(context);
    final muted = ExperienceFormStyle.line(context);
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Row(
      key: const ValueKey('home-news-page-controls'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.desktop)
          IconButton(
            key: const ValueKey('home-news-previous'),
            tooltip: '이전 소식',
            style: buttonStyle,
            onPressed: _index == 0 ? null : () => _goTo(_index - 1),
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
          ),
        for (var index = 0; index < widget.items.length; index++)
          Semantics(
            selected: index == _index,
            child: IconButton(
              key: ValueKey('home-news-page-$index'),
              tooltip: '${index + 1}번째 소식',
              style: buttonStyle,
              onPressed: () => _goTo(index),
              icon: AnimatedContainer(
                duration: SnapFitMotion.duration(context, SnapFitMotion.fast),
                width: index == _index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == _index ? ink : muted,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Semantics(
            liveRegion: true,
            label: '${_index + 1} / 총 ${widget.items.length}개 소식',
            child: ExcludeSemantics(
              child: Text(
                '${_index + 1} / ${widget.items.length}',
                key: const ValueKey('home-news-page-count'),
                style: ExperienceFormStyle.text(context, 12, secondary: true),
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
          ),
        ),
        if (widget.desktop)
          IconButton(
            key: const ValueKey('home-news-next'),
            tooltip: '다음 소식',
            style: buttonStyle,
            onPressed: _index == widget.items.length - 1
                ? null
                : () => _goTo(_index + 1),
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
          ),
      ],
    );
  }
}

/// Kept independent from routing and persistence so previews use production UI.
class HomeNewsSheetContent extends StatelessWidget {
  const HomeNewsSheetContent({
    super.key,
    required this.item,
    required this.onAction,
    required this.onClose,
    this.desktop = false,
    this.pageControls,
  });

  final HomeNewsItem item;
  final VoidCallback onAction;
  final VoidCallback onClose;
  final bool desktop;
  final Widget? pageControls;

  String get _eyebrow => switch (item.kind) {
    HomeNewsKind.monthlyDesign => '이달의 디자인',
    HomeNewsKind.attendance => '출석 혜택',
    HomeNewsKind.referral => '친구 초대',
    HomeNewsKind.monthReview => '${item.month.month}월 돌아보기',
  };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final horizontal = media.size.width < 360 ? 20.0 : 28.0;
    final bottom = math.max(media.padding.bottom, 18.0);
    final maxHeight = math.max(
      120.0,
      media.size.height - media.padding.top - (desktop ? 48 : 16),
    );
    return Material(
      key: ValueKey('home-news-${item.kind.name}'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!desktop)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: ExcludeSemantics(
                  child: Container(
                    width: 30,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ExperienceFormStyle.line(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: horizontal,
                right: horizontal - 10,
                top: desktop ? 14 : 0,
                bottom: 6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _eyebrow,
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        weight: FontWeight.w600,
                        secondary: true,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('home-news-close'),
                    tooltip: '닫기',
                    onPressed: onClose,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    visualDensity: VisualDensity.standard,
                    iconSize: 21,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                key: const ValueKey('home-news-content-scroll'),
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NewsArtwork(item: item, desktop: desktop),
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      child: Text(
                        item.title,
                        key: const ValueKey('home-news-title'),
                        style: ExperienceFormStyle.text(
                          context,
                          desktop ? 27 : 25,
                          weight: FontWeight.w700,
                        ).copyWith(height: 1.35, letterSpacing: -.8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.subtitle,
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        secondary: true,
                      ).copyWith(height: 1.65),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            if (pageControls != null)
              Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 0),
                child: pageControls,
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, bottom),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('home-news-action'),
                  onPressed: onAction,
                  style: ExperienceFormStyle.primary(context).copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
                  child: Text(item.actionLabel, textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsArtwork extends StatelessWidget {
  const _NewsArtwork({required this.item, required this.desktop});

  final HomeNewsItem item;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final compact = media.size.height < 650 || media.textScaler.scale(14) > 21;
    final artworkHeight = compact
        ? 144.0
        : desktop
        ? 232.0
        : 212.0;
    final palette = switch (item.kind) {
      HomeNewsKind.monthlyDesign =>
        dark ? const Color(0xFF28352F) : const Color(0xFFE9EEE7),
      HomeNewsKind.attendance =>
        dark ? const Color(0xFF15383E) : const Color(0xFFE3F5F7),
      HomeNewsKind.referral =>
        dark ? const Color(0xFF34332D) : const Color(0xFFF0ECE1),
      HomeNewsKind.monthReview =>
        dark ? const Color(0xFF293339) : const Color(0xFFEAF0F2),
    };
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          key: const ValueKey('home-news-artwork'),
          height: artworkHeight,
          width: double.infinity,
          child: ColoredBox(
            color: palette,
            child: LayoutBuilder(
              builder: (context, box) => FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: box.maxWidth,
                  height: desktop ? 232 : 212,
                  child: switch (item.kind) {
                    HomeNewsKind.monthlyDesign => _DesignArtwork(
                      covers: item.covers,
                      width: box.maxWidth,
                    ),
                    HomeNewsKind.attendance => _AttendanceArtwork(
                      rewardPoints: item.rewardPoints,
                    ),
                    HomeNewsKind.referral => _ReferralArtwork(
                      covers: item.covers,
                      width: box.maxWidth,
                    ),
                    HomeNewsKind.monthReview => _ReviewArtwork(
                      covers: item.covers,
                      month: item.month,
                      width: box.maxWidth,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _defaultDesignCovers = [
  HomeNewsCover(
    url: 'asset:assets/catalog_thumbnails/template_-9531.png',
    ratio: 1,
  ),
  HomeNewsCover(
    url: 'asset:assets/catalog_thumbnails/template_-9533.png',
    ratio: 1,
  ),
  HomeNewsCover(
    url: 'asset:assets/catalog_thumbnails/template_-9532.png',
    ratio: 1,
  ),
];

class _DesignArtwork extends StatelessWidget {
  const _DesignArtwork({required this.covers, required this.width});

  final List<HomeNewsCover> covers;
  final double width;

  @override
  Widget build(BuildContext context) {
    final shown = covers.isEmpty ? _defaultDesignCovers : covers;
    final side = math.min(164.0, width * .52);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (shown.length > 1)
          Transform.translate(
            offset: Offset(-width * .22, 5),
            child: Transform.rotate(
              angle: -.12,
              child: _BookCover(cover: shown[1], side: side * .79),
            ),
          ),
        if (shown.length > 2)
          Transform.translate(
            offset: Offset(width * .22, 7),
            child: Transform.rotate(
              angle: .12,
              child: _BookCover(cover: shown[2], side: side * .79),
            ),
          ),
        Transform.rotate(
          angle: -.035,
          child: _BookCover(cover: shown.first, side: side),
        ),
      ],
    );
  }
}

class _AttendanceArtwork extends StatelessWidget {
  const _AttendanceArtwork({this.rewardPoints});

  final int? rewardPoints;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF29474B) : const Color(0xFFFFFEFA);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: 28,
          top: 30,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 22,
            color: SnapFitColors.accent.withValues(alpha: .6),
          ),
        ),
        Transform.translate(
          offset: const Offset(-20, 0),
          child: Transform.rotate(
            angle: -.075,
            child: Container(
              width: 138,
              height: 157,
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(16),
                boxShadow: SnapFitShadow.card(dark),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '오늘',
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: SnapFitColors.actionAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(74, 42),
          child: Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SnapFitColors.actionAccent,
              shape: BoxShape.circle,
              border: Border.all(color: SnapFitColors.accent, width: 5),
              boxShadow: SnapFitShadow.card(dark),
            ),
            child: Text(
              rewardPoints == null ? '출석' : '${rewardPoints}P',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: SnapFitFonts.body,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferralArtwork extends StatelessWidget {
  const _ReferralArtwork({required this.covers, required this.width});

  final List<HomeNewsCover> covers;
  final double width;

  @override
  Widget build(BuildContext context) {
    final shown = covers.isEmpty ? _defaultDesignCovers : covers;
    final side = math.min(137.0, width * .43);
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(-width * .18, -9),
          child: Transform.rotate(
            angle: -.105,
            child: _BookCover(cover: shown.first, side: side),
          ),
        ),
        Transform.translate(
          offset: Offset(width * .17, 16),
          child: Transform.rotate(
            angle: .09,
            child: _BookCover(
              cover: shown.length > 1 ? shown[1] : shown.first,
              side: side,
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SnapFitColors.actionAccent,
            border: Border.all(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 4,
            ),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        ),
      ],
    );
  }
}

class _ReviewArtwork extends StatelessWidget {
  const _ReviewArtwork({
    required this.covers,
    required this.month,
    required this.width,
  });

  final List<HomeNewsCover> covers;
  final DateTime month;
  final double width;

  @override
  Widget build(BuildContext context) {
    final shown = covers;
    final side = math.min(156.0, width * .49);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 15,
          left: 18,
          child: Text(
            '${month.month.toString().padLeft(2, '0')} / ${month.year}',
            textScaler: TextScaler.noScaling,
            style: ExperienceFormStyle.text(
              context,
              11,
              weight: FontWeight.w600,
              secondary: true,
            ).copyWith(letterSpacing: 1.5),
          ),
        ),
        if (shown.length > 2)
          Transform.translate(
            offset: Offset(width * .24, 0),
            child: Transform.rotate(
              angle: .16,
              child: _PhotoPrint(cover: shown[2], side: side * .86, dark: dark),
            ),
          ),
        if (shown.length > 1)
          Transform.translate(
            offset: Offset(-width * .24, 3),
            child: Transform.rotate(
              angle: -.16,
              child: _PhotoPrint(cover: shown[1], side: side * .86, dark: dark),
            ),
          ),
        if (shown.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, 9),
            child: Transform.rotate(
              angle: -.035,
              child: _PhotoPrint(cover: shown.first, side: side, dark: dark),
            ),
          ),
        if (shown.isEmpty)
          Transform.translate(
            offset: const Offset(0, 12),
            child: Transform.rotate(
              angle: -.055,
              child: Container(
                key: const ValueKey('home-news-empty-record-artwork'),
                width: 136,
                height: 148,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFFDEE4E2)
                      : const Color(0xFFFFFEFA),
                  boxShadow: SnapFitShadow.card(dark),
                ),
                child: ColoredBox(
                  color: dark
                      ? const Color(0xFFBFD2D4)
                      : const Color(0xFFDDECEE),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: SnapFitColors.actionAccent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.cover, required this.side});

  final HomeNewsCover cover;
  final double side;

  @override
  Widget build(BuildContext context) {
    final ratio = cover.ratio.isFinite && cover.ratio > 0 ? cover.ratio : 1.0;
    final width = ratio >= 1 ? side : side * ratio;
    final height = ratio >= 1 ? side / ratio : side;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ExperienceFormStyle.surface(context),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .19),
            blurRadius: 14,
            offset: const Offset(2, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SnapfitImage(
              urlOrGs: cover.url,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              error: const _CoverFallback(),
              placeholder: const _CoverFallback(),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: .18),
                      Colors.white.withValues(alpha: .12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPrint extends StatelessWidget {
  const _PhotoPrint({
    required this.cover,
    required this.side,
    required this.dark,
  });

  final HomeNewsCover cover;
  final double side;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ratio = cover.ratio.isFinite && cover.ratio > 0 ? cover.ratio : 1.0;
    final photoWidth = ratio >= 1 ? side : side * ratio;
    final photoHeight = ratio >= 1 ? side / ratio : side;
    return Container(
      width: photoWidth + 12,
      height: photoHeight + 25,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 19),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFFDEE4E2) : const Color(0xFFFFFEFA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .17),
            blurRadius: 13,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: SnapfitImage(
        urlOrGs: cover.url,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        error: const _CoverFallback(),
        placeholder: const _CoverFallback(),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ExperienceFormStyle.selection(context),
    child: Center(
      child: Icon(
        Icons.photo_album_outlined,
        size: 40,
        color: ExperienceFormStyle.selectionInk(context),
      ),
    ),
  );
}
