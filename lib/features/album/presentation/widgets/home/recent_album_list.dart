import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/entities/album.dart';
import 'recent_album_card.dart';
import 'section_header.dart';
import 'home_album_helpers.dart';

class RecentAlbumList extends StatefulWidget {
  final List<Album> albums;
  final String currentUserId;
  final Function(Album) onTap;
  final VoidCallback onViewAll;

  const RecentAlbumList({
    super.key,
    required this.albums,
    required this.currentUserId,
    required this.onTap,
    required this.onViewAll,
  });

  @override
  State<RecentAlbumList> createState() => _RecentAlbumListState();
}

class _RecentAlbumListState extends State<RecentAlbumList> {
  late PageController _pageController;
  final double _viewportFraction = 0.70;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.albums.isEmpty) return const SizedBox.shrink();

    final displayAlbums = widget.albums.take(6).toList();
    final listHeight = 440.w;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: SectionHeader(
            title: '나의 기록들',
            subtitle: '일상의 소중한 순간을 기록해보세요',
            onViewAll: widget.onViewAll,
          ),
        ),
        // Efficient PageView with granular updates
        SizedBox(
          height: listHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: displayAlbums.length,
            physics: const BouncingScrollPhysics(),
            padEnds: true,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double currentPage = 0.0;
                  if (_pageController.hasClients && _pageController.position.haveDimensions) {
                    currentPage = _pageController.page ?? 0.0;
                  }
                  
                  // Calculate scale and focus based on position
                  double diff = (currentPage - index);
                  final scale = (1 - (diff.abs() * 0.1)).clamp(0.9, 1.0);
                  final isFocused = diff.abs() < 0.5;

                  // Logic to align the first item to the start
                  // If Vertical (ratio < 1.0) -> 0 padding (User Request)
                  // Else -> 20.w padding
                  final double screenWidth = 1.sw;
                  final double viewportFraction = 0.70;
                  final double centeredLeftEdge = (screenWidth * (1 - viewportFraction)) / 2;
                  
                  double targetLeftEdge = 20.w;
                  if (displayAlbums.isNotEmpty) {
                    final firstAlbum = displayAlbums[0];
                    final ratio = parseCoverRatio(firstAlbum.ratio);
                    if (ratio < 1.0) {
                      targetLeftEdge = 0;
                    }
                  }

                  final double maxShift = centeredLeftEdge - targetLeftEdge;
                  
                  // Apply shift only when near the first page (0.0 ~ 1.0)
                  final double currentShift = currentPage <= 1.0 
                      ? -maxShift * (1.0 - currentPage) 
                      : 0.0;

                  return Transform.translate(
                    offset: Offset(currentShift, 0),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: RepaintBoundary( // Isolate painting
                        child: Center(
                          child: RecentAlbumCard(
                            album: displayAlbums[index],
                            currentUserId: widget.currentUserId,
                            onTap: () => widget.onTap(displayAlbums[index]),
                            isFocused: isFocused,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
