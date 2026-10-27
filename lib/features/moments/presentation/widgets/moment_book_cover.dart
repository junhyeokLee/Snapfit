import 'package:flutter/material.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../domain/moment_record.dart';
import '../../domain/monthly_album_builder.dart';
import 'moments_widgets.dart';

/// Monthly books use the same physical trim and canvas as a newly created
/// SnapFit album. A preview must never turn that square into a portrait book.
class MomentBookCover extends StatelessWidget {
  const MomentBookCover({
    super.key,
    required this.month,
    this.photo,
    this.coverSize = monthlyMomentAlbumCoverSize,
    this.label,
  });

  final DateTime month;
  final MomentPhoto? photo;
  final CoverSize coverSize;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final canvas = coverCanvasBaseSize(coverSize);
    return Semantics(
      image: true,
      label: label ?? '${month.month}월 앨범 표지 구성 예시, ${coverSize.displayName}',
      child: AspectRatio(
        aspectRatio: canvas.width / canvas.height,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final width = bounds.maxWidth, height = bounds.maxHeight;
            final compact = width < 100;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: SnapFitColors.accentLight,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(3),
                  right: Radius.circular(8),
                ),
                border: Border.all(
                  color: SnapFitColors.accent.withValues(alpha: .18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 16,
                    offset: const Offset(4, 7),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(3),
                  right: Radius.circular(8),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: width * .025,
                      child: ColoredBox(
                        color: SnapFitColors.accent.withValues(alpha: .28),
                      ),
                    ),
                    Positioned(
                      left: width * .084,
                      top: height * .05,
                      right: width * .06,
                      height: height * .055,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${month.year} / ${month.month.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: SnapFitColors.accentInk,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * .084,
                      top: height * .115,
                      right: width * .06,
                      height: height * .125,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${month.month}월의 순간들',
                          style: const TextStyle(
                            color: Color(0xFF203139),
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.8,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * .076,
                      top: height * .286,
                      width: width * .876,
                      height: height * .662,
                      child: photo != null
                          ? MomentPhotoView(
                              photo: photo,
                              aspectRatio: .876 * width / (.662 * height),
                              label: '${month.month}월 앨범 표지 사진',
                              fit: BoxFit.contain,
                              backgroundColor: SnapFitColors.accentLight,
                            )
                          : ColoredBox(
                              color: Colors.white.withValues(alpha: .8),
                              child: Center(
                                child: compact
                                    ? const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: SnapFitColors.accentInk,
                                        size: 22,
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: SnapFitColors.accentInk,
                                            size: 30,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            '내 사진이 들어갈 자리',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF62757D),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
