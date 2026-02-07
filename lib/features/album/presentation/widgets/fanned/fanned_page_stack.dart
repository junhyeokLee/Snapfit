import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/album_page.dart';
import 'fanned_page_card.dart';
import 'fanned_page_content.dart';

/// Paper처럼: [frontPageIndex]가 맨 앞, 그 뒤로 부채꼴로 겹침. PageView 스와이프로 front 변경.
class FannedPageStack extends StatelessWidget {
  final int frontPageIndex;
  final int pageCount;
  final double pageWidth;
  final double pageHeight;
  final List<AlbumPage> pages;
  final CoverSize selectedCover;
  final CoverTheme selectedTheme;
  final Size? coverCanvasSize;
  final Album? currentAlbum;

  const FannedPageStack({
    super.key,
    required this.frontPageIndex,
    required this.pageCount,
    required this.pageWidth,
    required this.pageHeight,
    required this.pages,
    required this.selectedCover,
    required this.selectedTheme,
    this.coverCanvasSize,
    this.currentAlbum,
  });

  @override
  Widget build(BuildContext context) {
    if (pageCount == 0) {
      return SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: FannedPageCard(
          width: pageWidth,
          height: pageHeight,
          depth: 0,
          content: FannedPageContent(
            page: null,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            selectedCover: selectedCover,
            selectedTheme: selectedTheme,
            coverCanvasSize: coverCanvasSize,
            currentAlbum: currentAlbum,
          ),
        ),
      );
    }

    const int maxVisible = 5;
    const double offsetStep = 28.0;
    const double rotateZDeg = 4.0;
    const double maxFanY = 0.12;

    final count = math.min(maxVisible, pageCount - frontPageIndex);
    if (count <= 0) {
      return SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: FannedPageCard(
          width: pageWidth,
          height: pageHeight,
          depth: 0,
          content: FannedPageContent(
            page: pages[frontPageIndex.clamp(0, pageCount - 1)],
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            selectedCover: selectedCover,
            selectedTheme: selectedTheme,
            coverCanvasSize: coverCanvasSize,
            currentAlbum: currentAlbum,
          ),
        ),
      );
    }

    return SizedBox(
      width: pageWidth + 100.w,
      height: pageHeight + 50.h,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (i) {
          final pageIndex = frontPageIndex + i;
          final depth = i.toDouble();
          final t = count > 1 ? depth / (count - 1) : 0.0;
          final scale = 1.0 - t * 0.05;
          final offsetX = depth * offsetStep;
          final rotateZ = -depth * (rotateZDeg * 3.141592 / 180);
          final rotateY = -t * maxFanY;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..translate(offsetX, 0)
              ..rotateY(rotateY)
              ..rotateZ(rotateZ)
              ..scale(scale),
            child: FannedPageCard(
              width: pageWidth,
              height: pageHeight,
              depth: i,
              content: FannedPageContent(
                page: pages[pageIndex],
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                selectedCover: selectedCover,
                selectedTheme: selectedTheme,
                coverCanvasSize: coverCanvasSize,
                currentAlbum: currentAlbum,
              ),
            ),
          );
        }),
      ),
    );
  }
}
