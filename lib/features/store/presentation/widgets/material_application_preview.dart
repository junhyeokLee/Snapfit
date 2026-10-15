import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_style.dart';
import 'material_preview_composition.dart';

/// A sample composition using the unchanged catalog material, not a user album.
class MaterialApplicationPreview extends StatelessWidget {
  const MaterialApplicationPreview({
    super.key,
    required this.productKey,
    required this.type,
    required this.material,
    this.photoIndex = 0,
  });
  final String productKey, type;
  final Widget material;
  final int photoIndex;

  @override
  Widget build(BuildContext context) {
    final composition = MaterialPreviewComposition.forProduct(
      productKey,
      type,
      photoIndex: photoIndex,
    );
    final source = composition.letteringSourceSize;
    final materialLayer = Positioned.fromRect(
      rect: composition.materialRect,
      child: RepaintBoundary(
        key: const ValueKey('application-material'),
        child: source != null
            ? FittedBox(
                child: SizedBox(
                  width: source.width,
                  height: source.height,
                  child: material,
                ),
              )
            : material,
      ),
    );
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: MaterialPreviewComposition.canvas.width,
        height: MaterialPreviewComposition.canvas.height,
        child: ColoredBox(
          color: composition.paperColor,
          child: Stack(
            children: [
              if (composition.materialBelowPhoto) materialLayer,
              if (composition.photoRect case final Rect photoRect)
                Positioned.fromRect(
                  rect: photoRect,
                  child: Image.asset(
                    composition.photoAsset!,
                    key: const ValueKey('application-photo'),
                    fit: BoxFit.cover,
                    alignment: composition.photoAlignment,
                    cacheWidth: 1024,
                  ),
                ),
              if (!composition.materialBelowPhoto) materialLayer,
              if (composition.sampleTextRect case final Rect textRect)
                Positioned.fromRect(
                  rect: textRect,
                  child: Center(
                    child: Text(
                      composition.sampleText!,
                      textScaler: TextScaler.noScaling,
                      key: const ValueKey('application-sample-copy'),
                      textAlign: composition.serif
                          ? TextAlign.center
                          : TextAlign.left,
                      style: TextStyle(
                        fontFamily: composition.serif ? 'Eulyoo' : 'NotoSans',
                        fontSize: composition.serif ? 32 : 30,
                        height: 1.65,
                        letterSpacing: 0,
                        color: const Color(0xFF3D524B),
                      ),
                    ),
                  ),
                ),
              if (composition.captionRect case final Rect captionRect)
                Positioned.fromRect(
                  rect: captionRect,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == '프레임' ? '기억하고 싶은 한 장' : composition.caption,
                        textScaler: TextScaler.noScaling,
                        style: ExperienceStyle.text(
                          captionRect.height < 40 ? 18 : 28,
                          weight: FontWeight.w500,
                        ),
                      ),
                      if (captionRect.height >= 80) ...[
                        const SizedBox(height: 12),
                        Text(
                          '2026. 05. 24',
                          textScaler: TextScaler.noScaling,
                          style: ExperienceStyle.text(
                            16,
                            color: ExperienceStyle.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
