import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/utils/platform_ui.dart';
import '../../../domain/entities/album.dart';
import 'home_album_slider_card.dart';

/// 중앙 앨범을 강조하고 좌우 앨범이 살짝 보이도록 하는 홈 캐러셀
class HomeAlbumSlider extends ConsumerStatefulWidget {
  final List<Album> albums;
  final ValueChanged<Album>? onFocusedAlbumChanged;

  const HomeAlbumSlider({
    super.key,
    required this.albums,
    this.onFocusedAlbumChanged,
  });

  @override
  ConsumerState<HomeAlbumSlider> createState() => _HomeAlbumSliderState();
}

class _HomeAlbumSliderState extends ConsumerState<HomeAlbumSlider> {
  late final PageController _pageController;
  double _currentPage = 0;
  int _lastFocusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.59);
    _currentPage = _pageController.initialPage.toDouble();
    _lastFocusedIndex = _pageController.initialPage;
    _pageController.addListener(_handlePageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.albums.isEmpty) return;
      final index = _clampIndex(_lastFocusedIndex);
      widget.onFocusedAlbumChanged?.call(widget.albums[index]);
      _syncCurrentPage();
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCurrentPage());
  }

  void _handlePageChanged() => _syncCurrentPage();

  void _syncCurrentPage() {
    if (!_pageController.hasClients) return;
    final nextPage =
        _pageController.page ?? _pageController.initialPage.toDouble();
    if ((nextPage - _currentPage).abs() < 0.0001) return;
    final focusedIndex = _clampIndex(nextPage.round());
    if (widget.albums.isNotEmpty && _lastFocusedIndex != focusedIndex) {
      _lastFocusedIndex = focusedIndex;
      widget.onFocusedAlbumChanged?.call(widget.albums[focusedIndex]);
    }
    setState(() {
      _currentPage = nextPage;
    });
  }

  @override
  void didUpdateWidget(covariant HomeAlbumSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.albums.isEmpty) return;
    if (!identical(oldWidget.albums, widget.albums)) {
      final focusedIndex = _clampIndex(_currentPage.round());
      _lastFocusedIndex = focusedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onFocusedAlbumChanged?.call(widget.albums[focusedIndex]);
      });
    }
  }

  int _clampIndex(int index) {
    if (widget.albums.isEmpty) return 0;
    final lastIndex = widget.albums.length - 1;
    if (index < 0) return 0;
    if (index > lastIndex) return lastIndex;
    return index;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        final effectivePage = _pageController.hasClients
            ? (_pageController.page ?? _currentPage)
            : _currentPage;
        return PageView.builder(
          controller: _pageController,
          physics: platformScrollPhysics(),
          padEnds: true,
          clipBehavior: Clip.none,
          itemCount: widget.albums.length,
          itemBuilder: (context, index) {
            final album = widget.albums[index];
            return HomeAlbumSliderCard(
              key: ValueKey('${album.id}_${album.updatedAt}'),
              album: album,
              index: index,
              currentPage: effectivePage,
            );
          },
        );
      },
    );
  }
}
