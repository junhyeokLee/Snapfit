import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../../../core/utils/image_url_policy.dart';
import '../../../../../core/utils/storage_url_resolver.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../domain/entities/layer.dart';
import '../../../data/gallery/photo_asset_image_provider.dart';

Future<LayerModel?> showPhotoCropSheet(
  BuildContext context, {
  required LayerModel layer,
  File? file,
  String title = '사진 구도',
  Widget Function(LayerModel layer, Widget photo)? frameBuilder,
}) {
  FocusScope.of(context).unfocus();
  if (kIsWeb) {
    return showWebAwareDialog<LayerModel>(
      context: context,
      maxWidth: 1000,
      maxHeight: 740,
      builder: (_) => PhotoCropSheet(layer: layer, file: file, title: title, frameBuilder: frameBuilder),
    );
  }
  return showModalBottomSheet<LayerModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ExperienceFormStyle.surface(context),
    constraints: const BoxConstraints(maxWidth: 760),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (_) => PhotoCropSheet(
      layer: layer,
      file: file,
      title: title,
      frameBuilder: frameBuilder,
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
  });
  final LayerModel layer;
  final File? file;
  final String title;
  final Widget Function(LayerModel layer, Widget photo)? frameBuilder;

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

  @override
  void initState() {
    super.initState();
    _draft = widget.layer.copyWith();
    _photoRequest = _loadPhoto();
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

  void _reportPhoto({required bool ready, required int attempt}) {
    if (!mounted || attempt != _attempt) return;
    if (_photoReady == ready && _photoFailed == !ready) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt) return;
      if (_photoReady == ready && _photoFailed == !ready) return;
      setState(() {
        _photoReady = ready;
        _photoFailed = !ready;
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

  Widget _buildPhoto(LayerModel layer, int? decodeWidth) {
    final attempt = _attempt;
    return Image(
      key: ValueKey('crop-photo-$attempt'),
      // One bounded decode keeps the crop sharp and stable across rotation.
      image: _cropProvider(_provider!),
      fit: BoxFit.cover,
      alignment: layer.imageAlignment,
      frameBuilder: (context, child, frame, synchronouslyLoaded) {
        if (frame != null || synchronouslyLoaded) {
          _reportPhoto(ready: true, attempt: attempt);
          return child;
        }
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (context, error, stack) {
        _reportPhoto(ready: false, attempt: attempt);
        return const SizedBox.shrink();
      },
    );
  }

  ImageProvider _cropProvider(ImageProvider provider) => ResizeImage(
    provider,
    width: 1600,
    height: 1600,
    policy: ResizeImagePolicy.fit,
  );

  void _move(ScaleUpdateDetails details, Size viewport) {
    final zoom = (_gestureZoom * details.scale).clamp(1.0, 4.0);
    final alignment = _draft.imageAlignment;
    final x =
        (alignment.x -
                details.focalPointDelta.dx *
                    2 /
                    math.max(24, viewport.width * (zoom - 1 + .5)))
            .clamp(-1.0, 1.0);
    final y =
        (alignment.y -
                details.focalPointDelta.dy *
                    2 /
                    math.max(24, viewport.height * (zoom - 1 + .5)))
            .clamp(-1.0, 1.0);
    setState(
      () => _draft = _draft.copyWith(
        imageZoom: zoom,
        imageOffset: Offset(x * _draft.width * .5, -y * _draft.height * .5),
      ),
    );
  }

  Widget _photoPreview() => Padding(
    padding: const EdgeInsets.all(16),
    child: FutureBuilder<ImageProvider>(
      future: _photoRequest,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError || !snapshot.hasData || _photoFailed) {
          return _photoError();
        }
        _provider = snapshot.data;
        return LayoutBuilder(
          builder: (context, box) {
            final scale = math.min(
              box.maxWidth / _draft.width,
              box.maxHeight / _draft.height,
            );
            final viewport = Size(_draft.width * scale, _draft.height * scale);
            return Center(
              child: GestureDetector(
                key: const ValueKey('photo-crop-preview'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: !_photoReady
                    ? null
                    : (_) => _gestureZoom = _draft.imageZoom,
                onScaleUpdate: !_photoReady
                    ? null
                    : (details) => _move(details, viewport),
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
                          _draft.copyWith(position: Offset.zero, rotation: 0),
                        ],
                        width: viewport.width,
                        height: viewport.height,
                        designCanvasSize: Size(_draft.width, _draft.height),
                        photoBuilder: _buildPhoto,
                      ),
              ),
            );
          },
        );
      },
    ),
  );

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12 : 6)),
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
            height: kIsWeb ? available.maxHeight : math.min(
              available.maxHeight,
              MediaQuery.sizeOf(context).height * .9,
            ),
            child: AbsorbPointer(
              absorbing: _finishing,
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= (kIsWeb ? 720 : 540) &&
                      (kIsWeb || MediaQuery.orientationOf(context) == Orientation.landscape);
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ExperienceFormStyle.ink(context),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
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
                                            child: _zoomControls(),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _zoomControls(),
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
