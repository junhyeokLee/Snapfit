import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../../../core/utils/image_url_policy.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitRadius;
import '../../../../../core/utils/storage_url_resolver.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../domain/entities/layer.dart';
import '../../../data/gallery/photo_asset_image_provider.dart';
import '../../utils/photo_crop_geometry.dart';

/// A read-only page built from the caller's snapshot and the current crop draft.
class PhotoCropPageContext {
  const PhotoCropPageContext({required this.canvasSize, required this.builder});

  final Size canvasSize;
  final Widget Function(LayerModel draft) builder;

  bool get hasValidCanvas =>
      canvasSize.width.isFinite &&
      canvasSize.height.isFinite &&
      canvasSize.width > 0 &&
      canvasSize.height > 0;
}

Future<LayerModel?> showPhotoCropSheet(
  BuildContext context, {
  required LayerModel layer,
  File? file,
  String title = '사진 구도',
  Widget Function(LayerModel layer, Widget photo)? frameBuilder,
  PhotoCropPageContext? pageContext,
}) {
  FocusScope.of(context).unfocus();
  if (kIsWeb) {
    return showWebAwareDialog<LayerModel>(
      context: context,
      useRootNavigator: false,
      maxWidth: 1000,
      maxHeight: 740,
      builder: (_) => PhotoCropSheet(
        layer: layer,
        file: file,
        title: title,
        frameBuilder: frameBuilder,
        pageContext: pageContext,
      ),
    );
  }
  return showModalBottomSheet<LayerModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ExperienceFormStyle.surface(context),
    constraints: const BoxConstraints(maxWidth: 760),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SnapFitRadius.lg),
      ),
    ),
    builder: (_) => PhotoCropSheet(
      layer: layer,
      file: file,
      title: title,
      frameBuilder: frameBuilder,
      pageContext: pageContext,
    ),
  );
}

class PhotoCropSheet extends StatefulWidget {
  const PhotoCropSheet({
    super.key,
    required this.layer,
    this.file,
    this.title = '사진 구도',
    this.frameBuilder,
    this.pageContext,
  });
  final LayerModel layer;
  final File? file;
  final String title;
  final Widget Function(LayerModel layer, Widget photo)? frameBuilder;
  final PhotoCropPageContext? pageContext;

  @override
  State<PhotoCropSheet> createState() => _PhotoCropSheetState();
}

class _PhotoCropSheetState extends State<PhotoCropSheet> {
  late LayerModel _draft;
  double _gestureZoom = 1;
  late Future<ImageProvider> _photoRequest;
  ImageProvider? _provider;
  bool _photoReady = false;
  bool _photoFailed = false;
  bool _finishing = false;
  int _attempt = 0;
  Size? _photoSize;
  Size? _photoViewportSize;
  bool _showPageContext = false;
  final _photoBoundsKey = GlobalKey();
  ImageProvider? _sizeProvider;
  ImageStream? _sizeStream;
  ImageStreamListener? _sizeListener;
  int _sizeAttempt = -1;

  bool get _hasPageContext => widget.pageContext?.hasValidCanvas == true;
  bool get _pageContextActive => _hasPageContext && _showPageContext;

  @override
  void initState() {
    super.initState();
    _draft = widget.layer.copyWith();
    _photoRequest = _loadPhoto();
  }

  @override
  void dispose() {
    if (_sizeListener != null) _sizeStream?.removeListener(_sizeListener!);
    super.dispose();
  }

  void _observePhotoSize(ImageProvider provider) {
    if (_sizeProvider == provider && _sizeAttempt == _attempt) return;
    if (_sizeListener != null) _sizeStream?.removeListener(_sizeListener!);
    _sizeProvider = provider;
    _sizeAttempt = _attempt;
    final attempt = _attempt;
    _sizeListener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      info.dispose();
      _reportPhoto(ready: true, attempt: attempt, size: size);
    }, onError: (_, __) => _reportPhoto(ready: false, attempt: attempt));
    _sizeStream = _cropProvider(provider).resolve(
      createLocalImageConfiguration(context),
    )..addListener(_sizeListener!);
  }

  Future<ImageProvider> _loadPhoto() async {
    if (widget.file != null) return FileImage(widget.file!);
    if (widget.layer.asset != null) {
      return photoAssetImageProvider(widget.layer.asset!);
    }
    final source =
        [
              widget.layer.previewUrl,
              widget.layer.imageUrl,
              widget.layer.originalUrl,
            ]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .firstOrNull;
    if (source == null) throw StateError('photo_missing');
    final assetPath = bundledTemplateAssetPath(source);
    if (assetPath != null) return AssetImage(assetPath);
    final url = await resolveStorageImageUrl(source);
    return CachedNetworkImageProvider(url);
  }

  void _reportPhoto({required bool ready, required int attempt, Size? size}) {
    if (!mounted || attempt != _attempt) return;
    if (_photoReady == ready &&
        _photoFailed == !ready &&
        (size == null || size == _photoSize))
      return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt) return;
      if (_photoReady == ready &&
          _photoFailed == !ready &&
          (size == null || size == _photoSize))
        return;
      setState(() {
        _photoReady = ready;
        _photoFailed = !ready;
        if (size != null) _photoSize = size;
      });
    });
  }

  void _retryPhoto() {
    final previous = _provider;
    setState(() {
      _attempt++;
      _photoReady = false;
      _photoFailed = false;
      _photoRequest = () async {
        if (previous != null) await _cropProvider(previous).evict();
        return _loadPhoto();
      }();
    });
  }

  Widget _photoError() => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '사진을 불러오지 못했어요',
            style: TextStyle(
              color: ExperienceFormStyle.ink(context),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: _retryPhoto,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    ),
  );

  void _reportPhotoViewport(Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        size == _photoViewportSize)
      return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || size == _photoViewportSize) return;
      setState(() => _photoViewportSize = size);
    });
  }

  Widget _buildPhoto(LayerModel layer, int? decodeWidth) {
    final attempt = _attempt;
    return LayoutBuilder(
      builder: (context, box) {
        _reportPhotoViewport(box.biggest);
        return Image(
          key: _photoBoundsKey,
          // One bounded decode keeps the crop sharp and stable across rotation.
          image: _cropProvider(_provider!),
          fit: BoxFit.cover,
          alignment: layer.imageAlignment,
          frameBuilder: (context, child, frame, synchronouslyLoaded) {
            if (frame != null || synchronouslyLoaded) {
              _reportPhoto(ready: true, attempt: attempt);
              return child;
            }
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stack) {
            _reportPhoto(ready: false, attempt: attempt);
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  ImageProvider _cropProvider(ImageProvider provider) => ResizeImage(
    provider,
    width: 1600,
    height: 1600,
    policy: ResizeImagePolicy.fit,
  );

  void _move(ScaleUpdateDetails details) {
    final photoBox = _photoBoundsKey.currentContext?.findRenderObject();
    final photoSize = _photoSize;
    if (photoSize == null || photoBox is! RenderBox || !photoBox.hasSize)
      return;
    final zoom = (_gestureZoom * details.scale).clamp(1.0, 4.0);
    // Resolve in the photograph's own box, including any frame padding or
    // FittedBox transform, rather than the enclosing layer's dimensions.
    final local = photoBox.globalToLocal(details.focalPoint);
    final localPrevious = photoBox.globalToLocal(
      details.focalPoint - details.focalPointDelta,
    );
    final pivot = Offset(
      (1 + _draft.imageAlignment.x) * photoBox.size.width * .5,
      (1 + _draft.imageAlignment.y) * photoBox.size.height * .5,
    );
    // The render box is inside PhotoCropViewport's zoom transform. Convert
    // back to the stationary viewport while retaining the outer frame scale.
    final focalPoint = pivot + (local - pivot) * _draft.imageZoom;
    final delta = (local - localPrevious) * _draft.imageZoom;
    final alignment = PhotoCropGeometry.move(
      photo: photoSize,
      viewport: photoBox.size,
      alignment: _draft.imageAlignment,
      previousZoom: _draft.imageZoom,
      zoom: zoom,
      focalPoint: focalPoint,
      delta: delta,
    );
    setState(
      () => _draft = _draft.copyWith(
        imageZoom: zoom,
        imageOffset: Offset(
          alignment.x * _draft.width * .5,
          -alignment.y * _draft.height * .5,
        ),
      ),
    );
  }

  Widget _photoPreview() => _pageContextActive
      ? Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.pageContext!.canvasSize.aspectRatio,
              child: Semantics(
                container: true,
                label: '현재 사진 구도를 반영한 페이지',
                child: IgnorePointer(
                  child: FittedBox(
                    child: SizedBox(
                      key: const ValueKey('photo-crop-page-context'),
                      width: widget.pageContext!.canvasSize.width,
                      height: widget.pageContext!.canvasSize.height,
                      child: widget.pageContext!.builder(_draft),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      : Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<ImageProvider>(
            future: _photoRequest,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (snapshot.hasError || !snapshot.hasData || _photoFailed) {
                return _photoError();
              }
              _provider = snapshot.data;
              _observePhotoSize(_provider!);
              return LayoutBuilder(
                builder: (context, box) {
                  final scale = math.min(
                    box.maxWidth / _draft.width,
                    box.maxHeight / _draft.height,
                  );
                  final viewport = Size(
                    _draft.width * scale,
                    _draft.height * scale,
                  );
                  return Center(
                    child: GestureDetector(
                      key: const ValueKey('photo-crop-preview'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: !_photoReady
                          ? null
                          : (_) => _gestureZoom = _draft.imageZoom,
                      onScaleUpdate: !_photoReady ? null : _move,
                      child: widget.frameBuilder != null
                          ? SizedBox(
                              width: viewport.width,
                              height: viewport.height,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: _draft.width,
                                  height: _draft.height,
                                  child: Opacity(
                                    opacity: _draft.opacity,
                                    child: widget.frameBuilder!(
                                      _draft,
                                      _buildPhoto(_draft, null),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : TemplatePageRenderer(
                              layers: [
                                _draft.copyWith(
                                  position: Offset.zero,
                                  rotation: 0,
                                ),
                              ],
                              width: viewport.width,
                              height: viewport.height,
                              designCanvasSize: Size(
                                _draft.width,
                                _draft.height,
                              ),
                              photoBuilder: _buildPhoto,
                            ),
                    ),
                  );
                },
              );
            },
          ),
        );

  Widget _compositionControls() {
    final photoSize = _photoSize;
    final viewport = _photoViewportSize ?? Size(_draft.width, _draft.height);
    final covered = photoSize == null
        ? null
        : PhotoCropGeometry.coveredSize(
            photoSize,
            viewport,
            zoom: _draft.imageZoom,
          );
    final vertical =
        covered != null &&
        covered.height / viewport.height >= covered.width / viewport.width;
    final alignments = vertical
        ? const [Alignment.topCenter, Alignment.center, Alignment.bottomCenter]
        : const [Alignment.centerLeft, Alignment.center, Alignment.centerRight];
    final labels = vertical
        ? const ['위쪽', '중앙', '아래쪽']
        : const ['왼쪽', '중앙', '오른쪽'];
    final current = _draft.imageAlignment;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (covered != null &&
            (covered.width > viewport.width + .1 ||
                covered.height > viewport.height + .1))
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < alignments.length; i++)
                ChoiceChip(
                  key: ValueKey('photo-crop-anchor-$i'),
                  label: Text(labels[i]),
                  selected: vertical
                      ? (current.y - alignments[i].y).abs() < .001
                      : (current.x - alignments[i].x).abs() < .001,
                  onSelected: !_photoReady
                      ? null
                      : (_) => setState(
                          () => _draft = _draft.copyWith(
                            imageOffset: Offset(
                              (vertical ? current.x : alignments[i].x) *
                                  _draft.width *
                                  .5,
                              -(vertical ? alignments[i].y : current.y) *
                                  _draft.height *
                                  .5,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        _zoomControls(),
      ],
    );
  }

  Widget _zoomControls() => Row(
    children: [
      IconButton(
        tooltip: '사진 축소',
        icon: const Icon(Icons.zoom_out),
        onPressed: !_photoReady || _draft.imageZoom <= 1
            ? null
            : () => setState(
                () => _draft = _draft.copyWith(
                  imageZoom: (_draft.imageZoom - .1).clamp(1, 4),
                ),
              ),
      ),
      Expanded(
        child: Slider(
          key: const ValueKey('photo-crop-zoom'),
          value: _draft.imageZoom.clamp(1, 4),
          min: 1,
          max: 4,
          label: '${(_draft.imageZoom * 100).round()}%',
          onChanged: !_photoReady
              ? null
              : (value) =>
                    setState(() => _draft = _draft.copyWith(imageZoom: value)),
        ),
      ),
      IconButton(
        tooltip: '사진 확대',
        icon: const Icon(Icons.zoom_in),
        onPressed: !_photoReady || _draft.imageZoom >= 4
            ? null
            : () => setState(
                () => _draft = _draft.copyWith(
                  imageZoom: (_draft.imageZoom + .1).clamp(1, 4),
                ),
              ),
      ),
    ],
  );

  Widget _viewModeControl({bool compact = false}) {
    final label = _pageContextActive ? '사진 구도 조정' : '페이지에서 보기';
    final onPressed = !_photoReady || _finishing
        ? null
        : () => setState(() => _showPageContext = !_showPageContext);
    final icon = Icon(
      _pageContextActive ? Icons.crop : Icons.auto_stories_outlined,
      size: 18,
    );
    if (compact) {
      return IconButton(
        key: const ValueKey('photo-crop-context-toggle'),
        tooltip: label,
        onPressed: onPressed,
        icon: icon,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('photo-crop-context-toggle'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: ExperienceFormStyle.ink(context),
            textStyle: ExperienceFormStyle.text(context, 13),
          ),
          icon: icon,
          label: Text(label),
        ),
      ),
    );
  }

  void _finish({bool apply = false}) {
    if (!mounted ||
        _finishing ||
        ModalRoute.of(context)?.isCurrent == false ||
        apply && !_photoReady)
      return;
    setState(() => _finishing = true);
    Navigator.pop(context, apply ? _draft : null);
  }

  Widget _actionButtons() {
    final cancel = OutlinedButton(
      key: const ValueKey('photo-crop-cancel'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: ExperienceFormStyle.ink(context),
        textStyle: ExperienceFormStyle.text(context, 14),
        shape: const StadiumBorder(),
      ),
      onPressed: _finishing ? null : () => _finish(),
      child: const Text('취소'),
    );
    final apply = ElevatedButton(
      key: const ValueKey('photo-crop-apply'),
      style: ExperienceFormStyle.primary(context),
      onPressed: !_photoReady || _finishing ? null : () => _finish(apply: true),
      child: const Text('적용'),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cancel),
          const SizedBox(width: 12),
          Expanded(child: apply),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    final resized =
        scaffold != null && scaffold.widget.resizeToAvoidBottomInset != false;
    return Padding(
      padding: EdgeInsets.only(
        bottom: resized ? 0 : MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, available) => SizedBox(
            height: kIsWeb
                ? available.maxHeight
                : math.min(
                    available.maxHeight,
                    MediaQuery.sizeOf(context).height * .9,
                  ),
            child: AbsorbPointer(
              absorbing: _finishing,
              child: LayoutBuilder(
                builder: (context, box) {
                  final compactModeControl = box.maxHeight < 420;
                  final wide =
                      box.maxWidth >= (kIsWeb ? 720 : 540) &&
                      (kIsWeb ||
                          MediaQuery.orientationOf(context) ==
                              Orientation.landscape);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Tooltip(
                                message: widget.title,
                                child: Text(
                                  widget.title,
                                  maxLines: compactModeControl ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ExperienceFormStyle.ink(context),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            if (_hasPageContext && compactModeControl)
                              _viewModeControl(compact: true),
                            IconButton(
                              tooltip: '구도 초기화',
                              icon: const Icon(Icons.restart_alt),
                              onPressed: () => setState(
                                () => _draft = _draft.copyWith(
                                  imageZoom: 1,
                                  imageOffset: Offset.zero,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '닫기',
                              icon: const Icon(Icons.close),
                              onPressed: () => _finish(),
                            ),
                          ],
                        ),
                      ),
                      if (_hasPageContext && !compactModeControl)
                        _viewModeControl(),
                      if (wide)
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _photoPreview()),
                              SizedBox(
                                width: math.min(260, box.maxWidth * .36),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    16,
                                    12,
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: SingleChildScrollView(
                                            child: _pageContextActive
                                                ? const Text(
                                                    '제목과 사진의 겹침을 확인해보세요.',
                                                    textAlign: TextAlign.center,
                                                  )
                                                : _compositionControls(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _actionButtons(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Expanded(child: _photoPreview()),
                        if (!_pageContextActive)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: compactModeControl
                                    ? box.maxHeight * .34
                                    : double.infinity,
                              ),
                              child: SingleChildScrollView(
                                child: _compositionControls(),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _actionButtons(),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
