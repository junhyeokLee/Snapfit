import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/entities/album.dart';
import 'recent_album_card.dart';
import 'section_header.dart';

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
  // Viewport 0.70 allows ~273w slot (390 * 0.7).
  // Max Card Width (Square/Horizontal) = 266.w.
  // Gap = 3.5w each side.
  // Next card center distance = 273w.
  // Next Vertical (200w * 0.9 = 180w) -> Left edge distance from center = 273 - 90 = 183w.
  // Screen edge from center = 195w.
  // Visible part = 195 - 183 = 12w. (Visible)
  final double _viewportFraction = 0.70;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _viewportFraction);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Limit to 6 items
    final displayAlbums = widget.albums.take(6).toList();

    // Max Card Height (Vertical/Square): 266.w
    // Content Height: ~110.w
    // Extra padding for shadow/pop: 40.w
    final listHeight = 440.w;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: SectionHeader(
            title: '최근 작업 중인 앨범',
            onViewAll: widget.onViewAll,
          ),
        ),
        if (displayAlbums.isEmpty)
          SizedBox(
            height: 300.w,
            child: const Center(child: Text('최근 작업한 앨범이 없습니다.')),
          )
        else
          Builder(
            builder: (context) {
              // Calculate sliding offset to align first item with Title (20.w)
              // PageView centers items by default (padEnds: true).
              // At page 0, the slot center is at 0.5.sw.
              // Slot width = 1.sw * viewportFraction.
              // Current left edge of slot = 0.5.sw - (0.5.sw * viewportFraction).
              // Max shift needed = current left - 20.w.
              final double screenWidth = 1.sw;
              final double currentLeftEdge = 0.5 * screenWidth * (1 - _viewportFraction);
              final double targetLeftEdge = 20.w;
              final double maxShift = currentLeftEdge - targetLeftEdge;
              
              // Apply shift linearly from page 0 to 1
              final double currentShift = _currentPage <= 1.0 
                  ? -maxShift * (1.0 - _currentPage) 
                  : 0.0;

              return SizedBox(
                height: listHeight,
                child: Transform.translate(
                  offset: Offset(currentShift, 0),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: displayAlbums.length,
                    physics: const BouncingScrollPhysics(),
                    padEnds: true,
                    clipBehavior: Clip.none, // Allow items to shift outside bounds during transition
                    itemBuilder: (context, index) {
                      // Calculate scale
                      double diff = (_currentPage - index);
                      final scale = (1 - (diff.abs() * 0.1)).clamp(0.9, 1.0);
                      
                      final isFocused = diff.abs() < 0.5;

                      return Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: Center(
                          child: RecentAlbumCard(
                            album: displayAlbums[index],
                            currentUserId: widget.currentUserId,
                            onTap: () => widget.onTap(displayAlbums[index]),
                            isFocused: isFocused,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          ),
      ],
    );
  }
}
