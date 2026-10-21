import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'creation_workspace.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitMotion;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../../shared/widgets/gallery_thumb_tile.dart';
import '../../../domain/entities/layer.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../../store/presentation/widgets/template_book_artwork.dart';
import 'photo_crop_sheet.dart';
import '../../../data/gallery/browser_photo_asset.dart';
import '../../utils/photo_crop_geometry.dart';

/// A creation workspace outlives the photo-fill widget, but not its album.
class TemplatePhotoFillSession {
  int page = 0;
  AssetEntity? selectedPhoto;
  ({int page, String id})? selectedSlot;
  final List<AssetEntity> pendingPhotos = [];
  List<List<LayerModel>>? _pages;
  CoverSize? _cover;
  final List<_PhotoFillSnapshot> _undo = [];
  final List<_PhotoFillSnapshot> _redo = [];
  final Map<String, File> _files = {};
  final Map<AssetEntity, Future<File?>> _fileRequests = {};

  void reset() {
    page = 0;
    selectedPhoto = null;
    selectedSlot = null;
    pendingPhotos.clear();
    _pages = null;
    _cover = null;
    _undo.clear();
    _redo.clear();
    _files.clear();
    _fileRequests.clear();
  }

  void updateCover(List<LayerModel> cover) {
    final pages = _pages;
    if (pages == null || pages.isEmpty) return;
    // Older photo-fill undo entries must not undo a later cover edit.
    _pages = [
      [...cover],
      ...pages.skip(1),
    ];
    for (final stack in [_undo, _redo]) {
      for (var i = 0; i < stack.length; i++) {
        final old = stack[i];
        stack[i] = _PhotoFillSnapshot(
          pages: [
            [...cover],
            ...old.pages.skip(1),
          ],
          files: Map.of(old.files)
            ..removeWhere((key, _) => key.startsWith('0:')),
          photos: old.photos,
          selectedPhoto: old.selectedPhoto,
          selectedSlot: old.selectedSlot?.page == 0 ? null : old.selectedSlot,
          page: old.page,
        );
      }
    }
    _files.removeWhere((key, _) => key.startsWith('0:'));
    if (selectedSlot?.page == 0) selectedSlot = null;
  }
}

class TemplatePhotoFillStep extends ConsumerStatefulWidget {
  const TemplatePhotoFillStep({
    super.key,
    required this.pages,
    required this.cover,
    required this.onChanged,
    required this.onContinue,
    this.pickPhoto,
    this.pickPhotos,
    this.preserveTypography = false,
    this.session,
  });
  final List<List<LayerModel>> pages;
  final CoverSize cover;
  final ValueChanged<List<List<LayerModel>>> onChanged;
  final VoidCallback onContinue;
  final Future<AssetEntity?> Function()? pickPhoto;
  final Future<List<AssetEntity>?> Function()? pickPhotos;
  final bool preserveTypography;
  final TemplatePhotoFillSession? session;

  @override
  ConsumerState<TemplatePhotoFillStep> createState() =>
      _TemplatePhotoFillStepState();
}

class _TemplatePhotoFillStepState extends ConsumerState<TemplatePhotoFillStep> {
  static const _historyLimit = 30;
  late final TemplatePhotoFillSession _session;
  int get _page => _session.page;
  set _page(int value) => _session.page = value;
  int _revision = 0;
  bool _picking = false;
  List<List<LayerModel>> get _knownPages => _session._pages!;
  set _knownPages(List<List<LayerModel>> value) => _session._pages = value;
  List<_PhotoFillSnapshot> get _undo => _session._undo;
  List<_PhotoFillSnapshot> get _redo => _session._redo;
  Map<String, File> get _files => _session._files;
  Map<AssetEntity, Future<File?>> get _fileRequests => _session._fileRequests;
  List<AssetEntity> get _pendingPhotos => _session.pendingPhotos;
  AssetEntity? get _selectedPhoto => _session.selectedPhoto;
  set _selectedPhoto(AssetEntity? value) => _session.selectedPhoto = value;
  ({int page, String id})? get _selectedSlot => _session.selectedSlot;
  set _selectedSlot(({int page, String id})? value) =>
      _session.selectedSlot = value;
  final ScrollController _pageRailController = ScrollController();
  double _railItemExtent = 80;

  @override
  void dispose() {
    _pageRailController.dispose();
    super.dispose();
  }

  LayerModel? get _selectedLayer {
    final slot = _selectedSlot;
    return slot == null ? null : _layerAt(slot.page, slot.id);
  }

  LayerModel? _layerAt(int page, String id, {List<List<LayerModel>>? pages}) {
    final current = pages ?? widget.pages;
    return page < 0 || page >= current.length
        ? null
        : current[page]
              .where((layer) => layer.id == id && layer.type == LayerType.image)
              .firstOrNull;
  }

  List<List<LayerModel>> _copyPages(List<List<LayerModel>> pages) =>
      pages.map((page) => [...page]).toList();

  bool _samePages(List<List<LayerModel>> a, List<List<LayerModel>> b) {
    if (a.length != b.length) return false;
    for (var page = 0; page < a.length; page++) {
      if (a[page].length != b[page].length) return false;
      for (var layer = 0; layer < a[page].length; layer++) {
        if (!identical(a[page][layer], b[page][layer])) return false;
      }
    }
    return true;
  }

  _PhotoFillSnapshot _snapshot() => _PhotoFillSnapshot(
    pages: _copyPages(_knownPages),
    files: Map.of(_files),
    photos: List.of(_pendingPhotos),
    selectedPhoto: _selectedPhoto,
    selectedSlot: _selectedSlot,
    page: _page,
  );

  void _remember() {
    _undo.add(_snapshot());
    if (_undo.length > _historyLimit) _undo.removeAt(0);
    _redo.clear();
  }

  void _publish(List<List<LayerModel>> pages) {
    _revision++;
    _knownPages = _copyPages(pages);
    widget.onChanged(pages);
  }

  void _restore(
    List<_PhotoFillSnapshot> source,
    List<_PhotoFillSnapshot> destination,
  ) {
    if (_picking || source.isEmpty) return;
    destination.add(_snapshot());
    if (destination.length > _historyLimit) destination.removeAt(0);
    final snapshot = source.removeLast();
    final pages = _copyPages(snapshot.pages);
    final changed = !_samePages(_knownPages, pages);
    setState(() {
      _files
        ..clear()
        ..addAll(snapshot.files);
      _pendingPhotos
        ..clear()
        ..addAll(snapshot.photos);
      _selectedPhoto = snapshot.selectedPhoto;
      _selectedSlot = snapshot.selectedSlot;
      _page = snapshot.page;
      _revision++;
    });
    if (changed) _publish(pages);
    _loadFiles();
    _revealPage(_page);
  }

  List<Widget> _historyButtons() => [
    IconButton(
      key: const ValueKey('photo-fill-undo'),
      tooltip: '실행 취소',
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: const Icon(Icons.undo_rounded, size: 20),
      onPressed: _picking || _undo.isEmpty
          ? null
          : () => _restore(_undo, _redo),
    ),
    IconButton(
      key: const ValueKey('photo-fill-redo'),
      tooltip: '다시 실행',
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: const Icon(Icons.redo_rounded, size: 20),
      onPressed: _picking || _redo.isEmpty
          ? null
          : () => _restore(_redo, _undo),
    ),
  ];

  void _returnPhoto(AssetEntity? photo, List<List<LayerModel>> pages) {
    if (photo == null ||
        pages
            .expand((page) => page)
            .any((layer) => layer.asset?.id == photo.id) ||
        _pendingPhotos.any((pending) => pending.id == photo.id)) {
      return;
    }
    _pendingPhotos.add(photo);
    _selectedPhoto ??= photo;
  }

  bool _currentTarget(int revision, int page, LayerModel original) =>
      _revision == revision &&
      _selectedSlot == (page: page, id: original.id) &&
      identical(_layerAt(page, original.id), original);

  void _staleTarget() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('페이지가 변경됐어요. 사진을 다시 선택해주세요.')),
      );
    }
  }

  Future<File?> _fileFor(AssetEntity asset) => asset is BrowserPhotoAsset
      ? Future.value(null)
      : _fileRequests.putIfAbsent(asset, () => asset.file);

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? TemplatePhotoFillSession();
    if (_session._pages == null) {
      _knownPages = _copyPages(widget.pages);
      _session._cover = widget.cover;
    } else {
      _synchronizePages();
    }
    _page = _page.clamp(0, math.max(0, widget.pages.length - 1));
    _loadFiles();
    _revealPage(_page);
  }

  @override
  void didUpdateWidget(covariant TemplatePhotoFillStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _synchronizePages();
  }

  void _synchronizePages() {
    if (_session._pages == null) {
      _knownPages = _copyPages(widget.pages);
      _session._cover = widget.cover;
      _loadFiles();
      return;
    }
    if (_samePages(_knownPages, widget.pages) &&
        _session._cover?.sizeProductId == widget.cover.sizeProductId &&
        _session._cover?.ratio == widget.cover.ratio &&
        _session._cover?.realSize == widget.cover.realSize)
      return;
    // A new template must not inherit history or a pending edit from the old one.
    _revision++;
    _undo.clear();
    _redo.clear();
    _selectedSlot = null;
    _page = _page.clamp(0, math.max(0, widget.pages.length - 1));
    final retainedFiles = <String, File>{};
    for (var page = 0; page < widget.pages.length; page++) {
      for (final layer in widget.pages[page]) {
        final previous = page < _knownPages.length
            ? _knownPages[page].where((old) => old.id == layer.id).firstOrNull
            : null;
        final key = '$page:${layer.id}';
        if (layer.asset != null &&
            layer.asset?.id == previous?.asset?.id &&
            _files[key] != null) {
          retainedFiles[key] = _files[key]!;
        }
      }
    }
    _files
      ..clear()
      ..addAll(retainedFiles);
    _knownPages = _copyPages(widget.pages);
    _session._cover = widget.cover;
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final pages = _copyPages(_knownPages);
    final loaded =
        <({int page, String id}), ({File file, AssetEntity asset})>{};
    for (var page = 0; page < pages.length; page++) {
      for (final layer in pages[page]) {
        if (layer.asset == null) continue;
        File? file;
        try {
          file = await _fileFor(layer.asset!);
        } catch (_) {
          _fileRequests.remove(layer.asset);
          continue;
        }
        if (!mounted) return;
        if (file != null) {
          loaded[(page: page, id: layer.id)] = (
            file: file,
            asset: layer.asset!,
          );
        }
      }
    }
    if (mounted && loaded.isNotEmpty) {
      setState(() {
        for (final entry in loaded.entries) {
          if (_layerAt(
                entry.key.page,
                entry.key.id,
                pages: _knownPages,
              )?.asset?.id ==
              entry.value.asset.id) {
            _files['${entry.key.page}:${entry.key.id}'] = entry.value.file;
          }
        }
      });
    }
  }

  Future<void> _addPhotos() async {
    if (_picking) return;
    if (widget.pickPhoto != null && widget.pickPhotos == null) {
      _nextEmpty();
      return;
    }
    setState(() => _picking = true);
    try {
      final photos =
          await (widget.pickPhotos?.call() ??
              showPhotosSelectionSheet(context, ref));
      if (!mounted || photos == null) return;
      final additions = <AssetEntity>[];
      final ids = _pendingPhotos.map((photo) => photo.id).toSet();
      for (final photo in photos) {
        if (ids.add(photo.id)) additions.add(photo);
      }
      if (additions.isEmpty) return;
      _remember();
      setState(() {
        _pendingPhotos.addAll(additions);
        _selectedPhoto ??= _pendingPhotos.firstOrNull;
      });
    } catch (_) {
      _photoError();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _tapSlot(int page, String id) async {
    if (_picking) return;
    final layer = _layerAt(page, id);
    if (layer == null) return;
    setState(() => _selectedSlot = (page: page, id: id));
    if (layer.hasImageSource) return;
    final photo = _selectedPhoto;
    if (photo == null) {
      return _pick(page, id);
    }
    setState(() => _picking = true);
    try {
      await _placePhoto(page, layer, photo, revision: _revision);
    } catch (_) {
      _photoError();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _placePhoto(
    int page,
    LayerModel original,
    AssetEntity asset, {
    required int revision,
  }) async {
    if (!_currentTarget(revision, page, original)) {
      _staleTarget();
      return;
    }
    // Choosing the same local photograph again must retain its edited crop.
    if (original.asset?.id == asset.id) return;
    File? file;
    try {
      file = await _fileFor(asset);
    } catch (_) {
      _fileRequests.remove(asset);
      rethrow;
    }
    if (!mounted) return;
    if (!_currentTarget(revision, page, original)) {
      _staleTarget();
      return;
    }
    final localFile = file;
    if (localFile == null && asset is! BrowserPhotoAsset) {
      _fileRequests.remove(asset);
      throw StateError('Photo not available locally');
    }
    var replacement = original
        .copyWith(clearImage: true)
        .copyWith(asset: asset);
    final sourceSize = Size(asset.width.toDouble(), asset.height.toDouble());
    final reviewCrop = PhotoCropGeometry.needsReview(
      asset.orientation == 90 || asset.orientation == 270
          ? sourceSize.flipped
          : sourceSize,
      Size(original.width, original.height),
    );
    final coverHero = page == 0
        ? widget.pages.first
              .where((layer) => layer.type == LayerType.image)
              .reduce(
                (a, b) => a.width * a.height >= b.width * b.height ? a : b,
              )
              .id
        : null;
    if (reviewCrop && original.id == coverHero) {
      final result = await showPhotoCropSheet(
        context,
        layer: replacement,
        file: localFile,
        title: '표지 사진 구도',
        pageContext: _cropPageContext(
          page,
          targetId: original.id,
          targetFile: localFile,
        ),
      );
      if (!mounted || result == null) return;
      if (!_currentTarget(revision, page, original)) {
        _staleTarget();
        return;
      }
      replacement = result;
    }
    final index = widget.pages[page].indexWhere(
      (layer) => layer.id == original.id && layer.type == LayerType.image,
    );
    if (index < 0) return;
    final pages = widget.pages.map((p) => [...p]).toList();
    pages[page][index] = replacement;
    _remember();
    setState(() {
      if (localFile != null) {
        _files['$page:${original.id}'] = localFile;
      } else {
        _files.remove('$page:${original.id}');
      }
      _pendingPhotos.removeWhere((pending) => pending.id == asset.id);
      if (_selectedPhoto?.id == asset.id)
        _selectedPhoto = _pendingPhotos.firstOrNull;
      if (original.asset?.id != asset.id) _returnPhoto(original.asset, pages);
      _selectedSlot = (page: page, id: original.id);
    });
    _publish(pages);
    if (reviewCrop && original.id != coverHero) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('중요한 부분이 잘 보이는지 사진 구도를 확인해보세요.'),
          action: SnackBarAction(
            label: '구도 조정',
            onPressed: () {
              if (_picking || _layerAt(page, original.id) != replacement)
                return;
              setState(() {
                _page = page;
                _selectedSlot = (page: page, id: original.id);
              });
              _revealPage(page);
              _cropSelectedPhoto();
            },
          ),
        ),
      );
    }
  }

  void _photoError() {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 가져오지 못했어요. 다시 선택해주세요.')),
      );
  }

  Future<void> _pick(int page, String id) async {
    if (_picking) return;
    final original = _layerAt(page, id);
    if (original == null) return;
    final revision = _revision;
    setState(() => _picking = true);
    try {
      final asset =
          await (widget.pickPhoto?.call() ??
              showPhotoSelectionSheet(context, ref));
      if (!mounted || asset == null) return;
      await _placePhoto(page, original, asset, revision: revision);
    } catch (_) {
      _photoError();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  List<({int page, LayerModel layer})> get _slots => [
    for (var i = 0; i < widget.pages.length; i++)
      for (final layer in widget.pages[i])
        if (layer.type == LayerType.image) (page: i, layer: layer),
  ];

  void _nextEmpty({bool pick = true}) {
    final slots = _slots;
    final empty = slots.where((s) => !s.layer.hasImageSource).toList();
    if (empty.isEmpty) return;
    final cursor = slots.indexWhere(
      (slot) =>
          slot.page == _selectedSlot?.page &&
          slot.layer.id == _selectedSlot?.id,
    );
    final next = cursor < 0
        ? empty.where((s) => s.page >= _page).firstOrNull ?? empty.first
        : slots
                  .skip(cursor + 1)
                  .where((s) => !s.layer.hasImageSource)
                  .firstOrNull ??
              empty.first;
    setState(() {
      _page = next.page;
      _selectedSlot = (page: next.page, id: next.layer.id);
    });
    _revealPage(next.page);
    if (pick) _pick(next.page, next.layer.id);
  }

  void _revealPage(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageRailController.hasClients) return;
      final target = page * _railItemExtent;
      final offset = target.clamp(
        0.0,
        _pageRailController.position.maxScrollExtent,
      );
      if (SnapFitMotion.reduced(context)) {
        _pageRailController.jumpTo(offset);
        return;
      }
      _pageRailController.animateTo(
        offset,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _replaceSlotLayer(
    int page,
    LayerModel layer, {
    bool returnPhoto = false,
  }) {
    if (page < 0 || page >= widget.pages.length) return;
    final index = widget.pages[page].indexWhere((l) => l.id == layer.id);
    if (index < 0) return;
    final pages = widget.pages.map((p) => [...p]).toList();
    final original = pages[page][index];
    pages[page][index] = layer;
    _remember();
    if (returnPhoto) {
      setState(() {
        _returnPhoto(original.asset, pages);
        _files.remove('$page:${layer.id}');
        _selectedSlot = null;
      });
    }
    _publish(pages);
  }

  PhotoCropPageContext _cropPageContext(
    int page, {
    required String targetId,
    File? targetFile,
  }) {
    final snapshot = List<LayerModel>.of(widget.pages[page]);
    final canvas = coverCanvasBaseSize(widget.cover);
    final preserveTypography = widget.preserveTypography;
    final files = <String, File>{
      for (final layer in snapshot)
        if (_files['$page:${layer.id}'] case final file?) layer.id: file,
      if (targetFile != null) targetId: targetFile,
    };
    return PhotoCropPageContext(
      canvasSize: canvas,
      builder: (draft) => ColoredBox(
        color: Colors.white,
        child: TemplatePageRenderer(
          layers: [
            for (final layer in snapshot) layer.id == draft.id ? draft : layer,
          ],
          width: canvas.width,
          height: canvas.height,
          designCanvasSize: canvas,
          preserveTypography: preserveTypography,
          showCanvasChrome: false,
          cacheNetworkImages: true,
          localFiles: files,
          imageDecodeWidth: 1200,
        ),
      ),
    );
  }

  Future<void> _cropSelectedPhoto() async {
    final slot = _selectedSlot;
    final layer = _selectedLayer;
    if (_picking || slot == null || layer == null || !layer.hasImageSource)
      return;
    setState(() => _picking = true);
    final revision = _revision;
    try {
      final file = layer.asset == null ? null : await _fileFor(layer.asset!);
      if (!mounted) return;
      if (layer.asset != null &&
          layer.asset is! BrowserPhotoAsset &&
          file == null)
        throw StateError('Photo unavailable');
      if (!_currentTarget(revision, slot.page, layer)) {
        _staleTarget();
        return;
      }
      final result = await showPhotoCropSheet(
        context,
        layer: layer,
        file: file,
        pageContext: _cropPageContext(
          slot.page,
          targetId: layer.id,
          targetFile: file,
        ),
      );
      if (!mounted || result == null || slot.page >= widget.pages.length)
        return;
      if (!_currentTarget(revision, slot.page, layer)) {
        _staleTarget();
        return;
      }
      if (layer.imageZoom == result.imageZoom &&
          (layer.imageOffset ?? Offset.zero) ==
              (result.imageOffset ?? Offset.zero))
        return;
      _replaceSlotLayer(slot.page, result);
    } catch (_) {
      _fileRequests.remove(layer.asset);
      _photoError();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removeSelectedPhoto() {
    final slot = _selectedSlot, layer = _selectedLayer;
    if (_picking || slot == null || layer == null || !layer.hasImageSource)
      return;
    _replaceSlotLayer(
      slot.page,
      layer.copyWith(clearImage: true),
      returnPhoto: true,
    );
  }

  Widget _buildSlotTools({bool compact = false}) {
    final available = _selectedLayer?.hasImageSource == true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          constraints: compact
              ? const BoxConstraints.tightFor(width: 44, height: 44)
              : null,
          tooltip: '사진 구도 조정',
          icon: const Icon(Icons.crop),
          onPressed: _picking || !available ? null : _cropSelectedPhoto,
        ),
        IconButton(
          constraints: compact
              ? const BoxConstraints.tightFor(width: 44, height: 44)
              : null,
          tooltip: '사진 교체',
          icon: const Icon(Icons.swap_horiz),
          onPressed: _picking || !available ? null : _replaceSelectedPhoto,
        ),
        IconButton(
          constraints: compact
              ? const BoxConstraints.tightFor(width: 44, height: 44)
              : null,
          tooltip: '사진 제거',
          icon: const Icon(Icons.delete_outline),
          onPressed: _picking || !available ? null : _removeSelectedPhoto,
        ),
        IconButton(
          constraints: compact
              ? const BoxConstraints.tightFor(width: 44, height: 44)
              : null,
          tooltip: '사진 선택 해제',
          icon: const Icon(Icons.close),
          onPressed: _picking || !available
              ? null
              : () => setState(() => _selectedSlot = null),
        ),
      ],
    );
  }

  Future<void> _replaceSelectedPhoto() async {
    final slot = _selectedSlot;
    final layer = _selectedLayer;
    if (_picking || slot == null || layer == null) return;
    final photo = _selectedPhoto;
    if (photo == null) return _pick(slot.page, slot.id);
    setState(() => _picking = true);
    try {
      await _placePhoto(slot.page, layer, photo, revision: _revision);
    } catch (_) {
      _photoError();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Widget _buildPhotoTray({bool vertical = false, bool compact = false}) =>
      SizedBox(
        width: vertical ? 86 : null,
        height: vertical
            ? null
            : compact
            ? 64
            : 80,
        child: Flex(
          direction: vertical ? Axis.vertical : Axis.horizontal,
          children: [
            Expanded(
              child: ListView.separated(
                key: const ValueKey('photo-fill-tray'),
                scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: vertical ? 8 : 16,
                  vertical: 6,
                ),
                itemCount: _pendingPhotos.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8, height: 8),
                itemBuilder: (context, index) {
                  final photo = _pendingPhotos[index];
                  return Semantics(
                    button: true,
                    selected: _selectedPhoto == photo,
                    label: '선택한 사진 ${index + 1}',
                    child: InkWell(
                      key: ValueKey('tray-photo-${photo.id}'),
                      onTap: _picking
                          ? null
                          : () => setState(() => _selectedPhoto = photo),
                      child: Container(
                        width: compact ? 52 : 68,
                        height: compact ? 52 : 68,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _selectedPhoto == photo
                                ? ExperienceFormStyle.selectionInk(context)
                                : ExperienceFormStyle.line(context),
                            width: _selectedPhoto == photo ? 2 : 1,
                          ),
                        ),
                        child: GalleryThumbTile(
                          asset: photo,
                          isSelected: false,
                          simpleMode: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: '선택한 사진 제외',
              onPressed: _picking || _selectedPhoto == null
                  ? null
                  : () {
                      _remember();
                      setState(() {
                        _pendingPhotos.removeWhere(
                          (photo) => photo.id == _selectedPhoto?.id,
                        );
                        _selectedPhoto = _pendingPhotos.firstOrNull;
                      });
                    },
              icon: const Icon(Icons.remove_circle_outline, size: 22),
            ),
            const SizedBox(width: 8, height: 8),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('사진을 채울 페이지가 없어요'),
            TextButton(onPressed: widget.onContinue, child: const Text('돌아가기')),
          ],
        ),
      );
    }
    final slots = _slots;
    final filled = slots.where((s) => s.layer.hasImageSource).length;
    // Counts use the parent's accepted document, never a pending picker or the
    // local undo snapshot. A cancelled/failed/rejected photo cannot complete it.
    final allPhotosPlaced = slots.isNotEmpty && filled == slots.length;
    final ink = ExperienceFormStyle.ink(context);
    final muted = ExperienceFormStyle.muted(context);
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 520 &&
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final compact = !wide && constraints.maxHeight < 600;
          final lowWide = wide && constraints.maxHeight < 260;
          final tileHeight =
              (lowWide ? 52 : 88) +
              MediaQuery.textScalerOf(context).scale(11) * 1.5;
          _railItemExtent = wide
              ? tileHeight + 10
              : compact
              ? 68
              : 80;
          final pageIndex = wide && _page > 0
              ? ((_page - 1) ~/ 2) * 2 + 1
              : _page;
          final indices = [
            pageIndex,
            if (wide && pageIndex > 0 && pageIndex + 1 < widget.pages.length)
              pageIndex + 1,
          ];
          final pageLabel = pageIndex == 0
              ? '표지'
              : indices.length == 2
              ? '$pageIndex–${indices.last}쪽'
              : '$pageIndex쪽';
          final pageSlots = slots.where((slot) => indices.contains(slot.page));
          final remaining = pageSlots
              .where((slot) => !slot.layer.hasImageSource)
              .length;
          final positionLabel =
              '$pageLabel · ${pageSlots.isEmpty
                  ? '사진 자리 없음'
                  : remaining == 0
                  ? '사진 채움 완료'
                  : '사진 $remaining장 남음'}';
          final preview = LayoutBuilder(
            builder: (context, box) {
              final canvas = coverCanvasBaseSize(widget.cover);
              final scale = math.max(
                .01,
                math.min(
                  (box.maxWidth - 32) / (canvas.width * indices.length),
                  (box.maxHeight - 24) / canvas.height,
                ),
              );
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: lowWide ? 8 : 12,
                ),
                child: TemplateBookArtwork(
                  canvas: canvas,
                  firstPage: indices.first,
                  paired: indices.length == 2,
                  pageBuilder: (i, wrap) => FittedBox(
                    child: TemplatePageRenderer(
                      layers: widget.pages[i],
                      width: canvas.width,
                      height: canvas.height,
                      designCanvasSize: canvas,
                      preserveTypography: widget.preserveTypography,
                      wrapSpineArtwork: wrap,
                      cacheNetworkImages: true,
                      imageDecodeWidth:
                          (math.max(canvas.width, canvas.height) *
                                  scale *
                                  MediaQuery.devicePixelRatioOf(context) *
                                  1.5)
                              .ceil()
                              .clamp(320, 1600),
                      showCanvasChrome: false,
                      localFiles: {
                        for (final l in widget.pages[i])
                          if (_files['$i:${l.id}'] != null)
                            l.id: _files['$i:${l.id}']!,
                      },
                      // Only the native book's binding duplicate is read-only.
                      // Web renders the actual flat cover with wrap=false.
                      onLayerTap: !kIsWeb && i == 0 && !wrap
                          ? null
                          : (id) => _tapSlot(i, id),
                      selectedLayerId:
                          (kIsWeb || i != 0 || wrap) && _selectedSlot?.page == i
                          ? _selectedSlot?.id
                          : null,
                    ),
                  ),
                ),
              );
            },
          );
          final rail = ListView.separated(
            controller: _pageRailController,
            key: const ValueKey('photo-fill-page-rail'),
            scrollDirection: wide ? Axis.vertical : Axis.horizontal,
            padding: EdgeInsets.all(
              lowWide
                  ? 4
                  : compact
                  ? 8
                  : 12,
            ),
            itemCount: widget.pages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10, height: 10),
            itemBuilder: (context, index) {
              final selected = indices.contains(index);
              final pageSlots = widget.pages[index]
                  .where((l) => l.type == LayerType.image)
                  .toList();
              final pageFilled = pageSlots
                  .where((l) => l.hasImageSource)
                  .length;
              return Semantics(
                selected: selected,
                button: true,
                label:
                    '${index == 0 ? '표지' : '$index쪽'}, 사진 $pageFilled / ${pageSlots.length}',
                child: InkWell(
                  key: ValueKey('fill-page-$index'),
                  onTap: () => setState(() {
                    _page = index;
                    _selectedSlot = null;
                  }),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: compact ? 58 : 70,
                    height: wide ? tileHeight : null,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: selected
                          ? ExperienceFormStyle.selection(context)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? ExperienceFormStyle.selectionInk(
                                context,
                              ).withValues(alpha: .35)
                            : ExperienceFormStyle.line(context),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: compact ? 42 : 54,
                          height: lowWide
                              ? 32
                              : compact
                              ? 36
                              : 48,
                          child: FittedBox(
                            child: TemplatePageRenderer(
                              layers: widget.pages[index],
                              width: coverCanvasBaseSize(widget.cover).width,
                              height: coverCanvasBaseSize(widget.cover).height,
                              designCanvasSize: coverCanvasBaseSize(
                                widget.cover,
                              ),
                              showCanvasChrome: true,
                              imageDecodeWidth: 192,
                              preserveTypography: widget.preserveTypography,
                              localFiles: {
                                for (final l in widget.pages[index])
                                  if (_files['$index:${l.id}'] != null)
                                    l.id: _files['$index:${l.id}']!,
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                index == 0 ? '표지' : '$index',
                                style: TextStyle(fontSize: 11, color: ink),
                              ),
                              if (pageSlots.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                if (pageFilled == pageSlots.length)
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 12,
                                    color: ExperienceFormStyle.selectionInk(
                                      context,
                                    ),
                                  )
                                else
                                  Text(
                                    '$pageFilled/${pageSlots.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: muted,
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
            },
          );
          return Column(
            children: [
              Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(16, 4, 16, 6)
                    : lowWide
                    ? const EdgeInsets.fromLTRB(24, 4, 24, 4)
                    : const EdgeInsets.fromLTRB(24, 8, 24, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            wide || compact ? positionLabel : '사진 채우기',
                            maxLines: wide ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            key: wide || compact
                                ? const ValueKey('fill-current-page')
                                : null,
                            style: ExperienceFormStyle.text(
                              context,
                              wide || compact ? 13 : 20,
                              weight: wide || compact
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (wide || compact) ..._historyButtons(),
                        Semantics(
                          key: const ValueKey('fill-progress-status'),
                          container: true,
                          liveRegion: true,
                          label: allPhotosPlaced
                              ? '사진 ${slots.length}장 모두 배치됨. 표지를 확인해주세요.'
                              : '전체 사진 ${slots.length}장 중 $filled장 추가됨',
                          excludeSemantics: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (allPhotosPlaced) ...[
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: ExperienceFormStyle.selectionInk(
                                        context,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    '$filled / ${slots.length}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: allPhotosPlaced ? ink : muted,
                                    ),
                                  ),
                                ],
                              ),
                              if (allPhotosPlaced)
                                Text(
                                  '모두 배치됨',
                                  key: const ValueKey('fill-all-photos-placed'),
                                  style: ExperienceFormStyle.text(
                                    context,
                                    11,
                                    color: ExperienceFormStyle.selectionInk(
                                      context,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (filled < slots.length)
                          IconButton(
                            key: const ValueKey('fill-next-empty'),
                            tooltip: '다음 빈 자리',
                            icon: const Icon(
                              Icons.skip_next_outlined,
                              size: 21,
                            ),
                            onPressed: _picking
                                ? null
                                : () => _nextEmpty(pick: false),
                          ),
                      ],
                    ),
                    if (!wide && !compact) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              positionLabel,
                              key: const ValueKey('fill-current-page'),
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ),
                            ),
                          ),
                          ..._historyButtons(),
                        ],
                      ),
                    ],
                    if (slots.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: filled / slots.length,
                          minHeight: 2,
                          color: ExperienceFormStyle.selectionInk(context),
                          backgroundColor: ExperienceFormStyle.line(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          if (_pendingPhotos.isNotEmpty)
                            _buildPhotoTray(vertical: true),
                          Expanded(
                            child: CreationPaperStage(inset: 0, child: preview),
                          ),
                          SizedBox(width: 98, child: rail),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: CreationPaperStage(inset: 0, child: preview),
                          ),
                          SizedBox(
                            height:
                                (compact ? 72 : 96) +
                                MediaQuery.textScalerOf(context).scale(11) *
                                    1.5,
                            child: rail,
                          ),
                        ],
                      ),
              ),
              if (!wide && _selectedLayer?.hasImageSource == true)
                _buildSlotTools(compact: compact),
              if (!wide && _pendingPhotos.isNotEmpty)
                _buildPhotoTray(compact: compact),
              Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(16, 4, 16, 12)
                    : lowWide
                    ? const EdgeInsets.fromLTRB(24, 4, 24, 8)
                    : const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Row(
                  children: [
                    if (wide && _selectedLayer?.hasImageSource == true) ...[
                      _buildSlotTools(compact: true),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: wide ? 420 : double.infinity,
                          ),
                          child: LayoutBuilder(
                            builder: (context, actionsBox) {
                              final needsPhotos = filled < slots.length;
                              final add = FilledButton.icon(
                                key: const ValueKey('fill-add-photos'),
                                onPressed: _picking ? null : _addPhotos,
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 20,
                                ),
                                label: const Text('사진 추가'),
                                style: CreationStyle.primary(context),
                              );
                              final next = needsPhotos
                                  ? TextButton(
                                      key: const ValueKey('fill-continue'),
                                      onPressed: _picking
                                          ? null
                                          : widget.onContinue,
                                      child: const Text('나중에 채우기'),
                                    )
                                  : FilledButton(
                                      key: const ValueKey('fill-continue'),
                                      onPressed: _picking
                                          ? null
                                          : widget.onContinue,
                                      style: CreationStyle.primary(context),
                                      child: const Text('표지 확인'),
                                    );
                              final stacked = actionsBox.maxWidth < 380;
                              if (stacked) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (needsPhotos) ...[
                                      add,
                                      const SizedBox(height: 4),
                                    ],
                                    next,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  if (needsPhotos) ...[
                                    Expanded(child: add),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(child: next),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoFillSnapshot {
  const _PhotoFillSnapshot({
    required this.pages,
    required this.files,
    required this.photos,
    required this.selectedPhoto,
    required this.selectedSlot,
    required this.page,
  });

  final List<List<LayerModel>> pages;
  final Map<String, File> files;
  final List<AssetEntity> photos;
  final AssetEntity? selectedPhoto;
  final ({int page, String id})? selectedSlot;
  final int page;
}
