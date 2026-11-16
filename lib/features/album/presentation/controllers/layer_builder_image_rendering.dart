part of 'layer_builder.dart';

BoxFit _imageFitForLayerImpl(LayerModel layer) {
  // 템플릿이 있든 없든 모두 cover로 꽉 차게 표시
  return BoxFit.cover;
}

/// 사진 위치 조정용 imageOffset(픽셀)을 Image alignment(-1.0~1.0)로 변환
Alignment _imageAlignmentForLayerImpl(LayerModel layer) => layer.imageAlignment;

List<String> _photoSources(LayerModel layer) =>
    [layer.previewUrl, layer.imageUrl, layer.originalUrl]
        .whereType<String>()
        .map((source) => source.trim())
        .where((source) => source.isNotEmpty)
        .toSet()
        .toList(growable: false);

int? _decodeWidthForLayer(LayerBuilder builder, LayerModel layer) {
  final canvas =
      builder.interaction.isPreviewMode &&
          builder.previewImageDecodeWidth != null
      ? builder.getCoverSize()
      : const Size(1, 1);
  return previewLayerDecodeWidth(
    canvasDecodeWidth: builder.interaction.isPreviewMode
        ? builder.previewImageDecodeWidth
        : null,
    widthFraction: layer.width / canvas.width,
    heightFraction: layer.height / canvas.height,
    scale: layer.scale,
    zoom: layer.imageZoom,
  );
}

/// 이미지 레이어 빌드
Widget _buildImageImpl(
  LayerBuilder builder,
  LayerModel layer, {
  bool isCover = false,
  bool wrapSpine = false,
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
        child: builder._isolateArtwork(builder._buildDecoration(layer)),
      ),
    );
  }

  final fit = _imageFitForLayerImpl(layer);
  final alignment = _imageAlignmentForLayerImpl(layer);
  final decodeWidth = _decodeWidthForLayer(builder, layer);
  final curveSpine =
      wrapSpine &&
      isCover &&
      builder.interaction.isPreviewMode &&
      builder.printImages == null;

  Widget framePhoto(Widget photo) => curveSpine
      ? builder._isolateArtwork(_buildFramedImageImpl(builder, layer, photo))
      : builder._buildFramedImage(layer, photo);

  Widget previewPhoto(ImageProvider provider, {bool decoded = false}) {
    final image = decoded
        ? provider
        : ResizeImage.resizeIfNeeded(decodeWidth, null, provider);
    return curveSpine
        ? AlbumSpineImage(
            image: image,
            alignment: alignment,
            zoom: layer.imageZoom,
          )
        : Image(
            image: image,
            fit: fit,
            alignment: alignment,
            filterQuality: FilterQuality.medium,
          );
  }

  if (builder.printImages != null) {
    final url = layer.originalUrl ?? layer.imageUrl ?? layer.previewUrl;
    final image = builder.printImages![url];
    if (image == null)
      throw StateError('print_original_not_loaded:${layer.id}');
    final contain =
        layer.imageBackground != 'rasterCover' &&
        (layer.type == LayerType.sticker ||
            (url?.startsWith('asset:assets/sticker/') ?? false));
    return builder.interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: builder._buildFramedImage(
          layer,
          RawImage(
            image: image,
            fit: contain ? BoxFit.contain : fit,
            alignment: alignment,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  if (layer.asset != null) {
    // 아직 업로드 전: 로컬 AssetEntity로 표시
    return builder.interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: framePhoto(
          ActivePhoto(
            builder: (_) => previewPhoto(photoAssetImageProvider(layer.asset!)),
          ),
        ),
      ),
    );
  }

  final sources = _photoSources(layer);
  final url = sources.firstOrNull;
  if (url == null) {
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
  if (sources.length == 1 && url.startsWith('asset:')) {
    final assetPath = url.substring('asset:'.length);
    final shouldContainAsset =
        layer.imageBackground != 'rasterCover' &&
        (layer.type == LayerType.sticker ||
            assetPath.startsWith('assets/sticker/'));
    return builder.interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: framePhoto(
          ActivePhoto(
            builder: (_) => curveSpine
                ? previewPhoto(AssetImage(assetPath))
                : Image.asset(
                    assetPath,
                    fit: shouldContainAsset ? BoxFit.contain : fit,
                    alignment: alignment,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: decodeWidth,
                  ),
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
      child: framePhoto(
        SnapfitImage(
          key: ValueKey(layer.id), // Stable key to prevent reloading
          urlOrGs: url,
          fallbackSources: sources.skip(1).toList(growable: false),
          automaticStorageRefresh: true,
          fit: fit,
          alignment: alignment,
          memCacheWidth: decodeWidth,
          filterQuality: FilterQuality.medium,
          // Keep web photos equally smooth before and after saving. The
          // cached provider and URL stay unchanged; only sampling matches the
          // existing local preview instead of CachedNetworkImage's low default.
          imageBuilder: curveSpine || kIsWeb
              ? (context, provider) => previewPhoto(provider, decoded: true)
              : null,
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
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const ExperienceIcon('ImagePlus', size: 16, color: Colors.white),
      ),
    ),
  );
  return builder._buildFramedImage(layer, placeholder);
}
