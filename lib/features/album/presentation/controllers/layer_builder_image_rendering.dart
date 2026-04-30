part of 'layer_builder.dart';

BoxFit _imageFitForLayerImpl(LayerModel layer) {
  // 템플릿이 있든 없든 모두 cover로 꽉 차게 표시
  return BoxFit.cover;
}

/// 사진 위치 조정용 imageOffset(픽셀)을 Image alignment(-1.0~1.0)로 변환
Alignment _imageAlignmentForLayerImpl(LayerModel layer) {
  final offset = layer.imageOffset ?? Offset.zero;
  if (offset == Offset.zero) return Alignment.center;

  // 레이어 박스 크기를 기준으로 정규화해서 -1.0 ~ 1.0 범위로 매핑
  final w = layer.width > 0 ? layer.width : 1.0;
  final h = layer.height > 0 ? layer.height : 1.0;
  final nx = (offset.dx / (w * 0.5)).clamp(-1.0, 1.0);
  // 화면에서 손가락을 위로 드래그하면 offset.dy는 -값이므로,
  // 위로 드래그했을 때 사진 내용도 함께 위로 올라가도록 부호를 반대로 매핑
  final ny = (-offset.dy / (h * 0.5)).clamp(-1.0, 1.0);
  return Alignment(nx, ny);
}

/// 이미지 레이어 빌드
Widget _buildImageImpl(
  LayerBuilder builder,
  LayerModel layer, {
  bool isCover = false,
}) {
  // 편집 중인 레이어면 숨김
  if (builder._isEditing(layer)) return const SizedBox.shrink();

  if (layer.type == LayerType.decoration) {
    return builder.interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: builder._buildDecoration(layer),
      ),
    );
  }

  final fit = _imageFitForLayerImpl(layer);
  final alignment = _imageAlignmentForLayerImpl(layer);

  if (layer.asset != null) {
    // 아직 업로드 전: 로컬 AssetEntity로 표시
    return builder.interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: builder._buildFramedImage(
          layer,
          Image(
            image: AssetEntityImageProvider(layer.asset!),
            fit: fit,
            alignment: alignment,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }

  final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
  if (url == null || url.isEmpty) {
    return builder.interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: _buildImagePlaceholderImpl(builder, layer),
      ),
    );
  }

  // 앱 번들 에셋 기반 스티커(예: asset:assets/sticker/scrap1.png)
  if (url.startsWith('asset:')) {
    final assetPath = url.substring('asset:'.length);
    final shouldContainAsset =
        layer.type == LayerType.sticker ||
        assetPath.startsWith('assets/sticker/');
    return builder.interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: builder._buildFramedImage(
          layer,
          Image.asset(
            assetPath,
            fit: shouldContainAsset ? BoxFit.contain : fit,
            alignment: alignment,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }

  return builder.interaction.buildInteractiveLayer(
    layer: layer,
    baseWidth: layer.width,
    baseHeight: layer.height,
    isCover: isCover,
    child: Opacity(
      opacity: layer.opacity,
      child: builder._buildFramedImage(
        layer,
        SnapfitImage(
          key: ValueKey(layer.id), // Stable key to prevent reloading
          urlOrGs: url,
          fit: fit,
          alignment: alignment,
        ),
      ),
    ),
  );
}

/// 빈 이미지 슬롯(플레이스홀더) – 템플릿 적용 후 사진을 넣을 자리
Widget _buildImagePlaceholderImpl(LayerBuilder builder, LayerModel layer) {
  final placeholder = Container(
    width: layer.width,
    height: layer.height,
    decoration: BoxDecoration(
      color: const Color(0xFFECECEC),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0xFFD1D1D1), width: 1),
    ),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.32),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add_a_photo, size: 16, color: Colors.white),
      ),
    ),
  );
  return builder._buildFramedImage(layer, placeholder);
}
