import 'package:flutter/material.dart';

import '../../../../moments/domain/moment_record.dart';
import '../../../../moments/presentation/widgets/moments_widgets.dart';

/// 원본 사진과 편집한 지면 모두 자신의 비율 안에서 온전히 보여 준다.
class HomeMomentPhoto extends StatelessWidget {
  const HomeMomentPhoto({
    super.key,
    required this.photo,
    required this.width,
    required this.height,
    this.imageDecodeWidth = 384,
  });

  final MomentPhoto photo;
  final double width, height;
  final int imageDecodeWidth;

  @override
  Widget build(BuildContext context) {
    final ratio = momentPhotoAspect(photo);
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(ratio, 1),
      Size(width, height),
    ).destination;
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: SizedBox(
          key: ValueKey('home-moment-photo-frame-${photo.id}'),
          width: fitted.width,
          height: fitted.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: MomentPhotoView(
              key: ValueKey(photo.storageUri),
              photo: photo,
              aspectRatio: ratio,
              fit: BoxFit.contain,
              imageDecodeWidth: imageDecodeWidth,
              placeholder: const SizedBox.shrink(),
              error: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
