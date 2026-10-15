import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/constants/snapfit_colors.dart';
import '../../features/album/data/api/album_provider.dart';
import '../../features/album/presentation/viewmodels/gallery_notifier.dart';
import 'gallery_thumb_tile.dart';
import 'experience_form_style.dart';
import 'browser_photo_selection_sheet.dart';

class GalleryEmptyOrErrorPanel extends StatelessWidget {
  const GalleryEmptyOrErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onOpenPhotoSettings,
  });

  final Object? message;
  final VoidCallback onRetry;
  final VoidCallback onOpenPhotoSettings;

  bool get _isPermissionError {
    final text = message?.toString() ?? '';
    return text.contains('권한') || text.toLowerCase().contains('permission');
  }

  @override
  Widget build(BuildContext context) {
    final title = _isPermissionError ? '사진 접근 권한이 필요해요' : '이미지 앨범이 비어 있어요';
    final body = _isPermissionError
        ? '설정에서 사진을 몇 장 더 허용한 뒤 다시 불러오면 Snapfit이 기기 안에서만 사진을 보여줘요.'
        : '다른 앨범을 고르거나 사진 접근 범위를 넓힌 뒤 다시 불러와 주세요.';
    final retryLabel = _isPermissionError ? '다시 시도' : '다시 불러오기';

    return Container(
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SnapFitColors.overlayLightOf(context),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  _isPermissionError
                      ? Icons.photo_library_outlined
                      : Icons.photo_outlined,
                  size: 34,
                  color: SnapFitColors.accent,
                ),
              ),
              SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
              SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
              SizedBox(height: 18),
              if (_isPermissionError) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onOpenPhotoSettings,
                    icon: Icon(Icons.settings_outlined, size: 18),
                    label: const Text('사진 권한 열기'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: SnapFitColors.accent,
                      foregroundColor: Colors.white,
                      textStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text(retryLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SnapFitColors.textPrimaryOf(context),
                    side: BorderSide(
                      color: SnapFitColors.overlayLightOf(context),
                    ),
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-photo callers retain immediate selection; template filling uses a tray.
Future<AssetEntity?> showPhotoSelectionSheet(
  BuildContext context,
  WidgetRef ref, {
  void Function(AssetEntity asset)? onSelect,
}) async {
  final selected = await _showPhotoSheet(context, ref, maxSelection: 1);
  final photo = selected?.firstOrNull;
  if (photo != null) onSelect?.call(photo);
  return photo;
}

Future<List<AssetEntity>?> showPhotosSelectionSheet(
  BuildContext context,
  WidgetRef ref, {
  int maxSelection = 100,
}) => _showPhotoSheet(context, ref, maxSelection: maxSelection);

Future<List<AssetEntity>?> _showPhotoSheet(
  BuildContext context,
  WidgetRef ref, {
  required int maxSelection,
}) {
  assert(maxSelection > 0);
  if (kIsWeb) {
    return showBrowserPhotosSelectionSheet(context, maxSelection: maxSelection);
  }
  final current = ref.read(galleryProvider);
  if (!current.isLoading) {
    ref
        .read(galleryProvider.notifier)
        .fetchInitialData(albumId: current.selectedAlbum?.id);
  }
  return showModalBottomSheet<List<AssetEntity>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 760),
    backgroundColor: Colors.transparent,
    builder: (context) => _ResizablePhotoSheet(maxSelection: maxSelection),
  );
}

String _albumName(AssetPathEntity? album) {
  if (album == null || album.isAll) return '전체 사진';
  return album.name == 'Recent' ? '최근' : album.name;
}

class _ResizablePhotoSheet extends StatefulWidget {
  const _ResizablePhotoSheet({required this.maxSelection});
  final int maxSelection;

  @override
  State<_ResizablePhotoSheet> createState() => _ResizablePhotoSheetState();
}

class _ResizablePhotoSheetState extends State<_ResizablePhotoSheet> {
  final _controller = DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      final initial = landscape ? .94 : .82;
      final minimum = landscape ? .82 : .54;
      return DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: initial,
        maxChildSize: .96,
        minChildSize: minimum,
        snap: true,
        snapSizes: [initial],
        shouldCloseOnMinExtent: false,
        expand: false,
        builder: (context, scrollController) => _PhotoSelectionSheet(
          controller: scrollController,
          maxSelection: widget.maxSelection,
          onResize: (details) {
            if (!_controller.isAttached || constraints.maxHeight <= 0) return;
            _controller.jumpTo(
              (_controller.size - details.delta.dy / constraints.maxHeight)
                  .clamp(minimum, .96),
            );
          },
          onResizeEnd: (details) {
            if (!_controller.isAttached) return;
            final stops = [minimum, initial, .96];
            final velocity = details.primaryVelocity ?? 0;
            final size = _controller.size;
            final target = velocity < -650
                ? stops.where((stop) => stop > size + .02).firstOrNull ?? .96
                : velocity > 650
                ? stops.where((stop) => stop < size - .02).lastOrNull ?? minimum
                : (stops..sort(
                        (a, b) => (a - size).abs().compareTo((b - size).abs()),
                      ))
                      .first;
            _controller.animateTo(
              target,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            );
          },
        ),
      );
    },
  );
}

class _PhotoSelectionSheet extends ConsumerStatefulWidget {
  const _PhotoSelectionSheet({
    required this.controller,
    required this.maxSelection,
    required this.onResize,
    required this.onResizeEnd,
  });
  final ScrollController controller;
  final int maxSelection;
  final GestureDragUpdateCallback onResize;
  final GestureDragEndCallback onResizeEnd;
  @override
  ConsumerState<_PhotoSelectionSheet> createState() =>
      _PhotoSelectionSheetState();
}

class _PhotoSelectionSheetState extends ConsumerState<_PhotoSelectionSheet> {
  final Map<String, AssetEntity> _selected = {};
  bool _selectedOnly = false;
  bool get _multiple => widget.maxSelection > 1;

  void _toggleSelectedOnly() {
    if (widget.controller.hasClients) widget.controller.jumpTo(0);
    setState(() => _selectedOnly = !_selectedOnly);
  }

  void _select(AssetEntity asset) {
    if (!_multiple) {
      Navigator.pop(context, [asset]);
      return;
    }
    if (_selected.containsKey(asset.id)) {
      setState(() {
        _selected.remove(asset.id);
        if (_selected.isEmpty) _selectedOnly = false;
      });
    } else if (_selected.length < widget.maxSelection) {
      setState(() => _selected[asset.id] = asset);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('한 번에 최대 ${widget.maxSelection}장까지 선택할 수 있어요.')),
      );
    }
  }

  Future<void> _chooseAlbum(GalleryState state) async {
    final selected = await showModalBottomSheet<AssetPathEntity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 760),
      backgroundColor: SnapFitColors.surfaceOf(context),
      builder: (context) => _GalleryAlbumSelectionSheet(state: state),
    );
    if (!mounted || selected == null) return;
    if (widget.controller.hasClients) widget.controller.jumpTo(0);
    await ref.read(galleryProvider.notifier).selectAlbum(selected);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryProvider);
    final photos = _selectedOnly
        ? _selected.values.toList(growable: false)
        : state.images;
    final selectionOrder = {
      for (final (index, id) in _selected.keys.indexed) id: index + 1,
    };
    return Material(
      color: SnapFitColors.surfaceOf(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            GestureDetector(
              key: const ValueKey('gallery-resize-handle'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: widget.onResize,
              onVerticalDragEnd: widget.onResizeEnd,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 2),
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ExperienceFormStyle.line(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '사진 선택',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ExperienceFormStyle.text(
                              context,
                              16,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_multiple)
                          Text(
                            '${_selected.length}/${widget.maxSelection}',
                            style: ExperienceFormStyle.text(
                              context,
                              13,
                              secondary: true,
                            ),
                          ),
                        if (_multiple)
                          IconButton(
                            key: const ValueKey('gallery-selected-only'),
                            tooltip: _selectedOnly ? '전체 사진 보기' : '선택한 사진만 보기',
                            isSelected: _selectedOnly,
                            onPressed: _selected.isEmpty
                                ? null
                                : _toggleSelectedOnly,
                            color: _selectedOnly
                                ? ExperienceFormStyle.selectionInk(context)
                                : ExperienceFormStyle.ink(context),
                            icon: const Icon(Icons.checklist_rounded, size: 22),
                          ),
                        IconButton(
                          tooltip: '사진 선택 닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 22),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (state.albums.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 16, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const ValueKey('gallery-album-switch'),
                          onPressed: _selectedOnly
                              ? _toggleSelectedOnly
                              : () => _chooseAlbum(state),
                          style: TextButton.styleFrom(
                            foregroundColor: ExperienceFormStyle.ink(context),
                            minimumSize: const Size(44, 44),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedOnly
                                    ? Icons.arrow_back
                                    : Icons.photo_library_outlined,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _selectedOnly
                                      ? '선택한 사진'
                                      : _albumName(state.selectedAlbum),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (!_selectedOnly)
                                const Icon(Icons.expand_more, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedOnly)
                      IconButton(
                        tooltip: '모든 선택 해제',
                        onPressed: () => setState(() {
                          _selected.clear();
                          _selectedOnly = false;
                        }),
                        icon: const Icon(Icons.deselect_outlined, size: 20),
                      )
                    else
                      Text(
                        '최신순',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: state.selectedAlbum == null && state.error != null
                  ? GalleryEmptyOrErrorPanel(
                      message: state.error,
                      onRetry: () =>
                          ref.read(galleryProvider.notifier).fetchInitialData(),
                      onOpenPhotoSettings: PhotoManager.openSetting,
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.depth == 0 &&
                            !_selectedOnly &&
                            state.error == null &&
                            notification.metrics.extentAfter < 400) {
                          ref.read(galleryProvider.notifier).loadMore();
                        }
                        return false;
                      },
                      child: RefreshIndicator(
                        color: ExperienceFormStyle.selectionInk(context),
                        notificationPredicate: (notification) =>
                            !_selectedOnly && notification.depth == 0,
                        onRefresh: () => ref
                            .read(galleryProvider.notifier)
                            .fetchInitialData(albumId: state.selectedAlbum?.id),
                        child: CustomScrollView(
                          key: ValueKey(
                            'gallery-grid-${state.selectedAlbum?.id}-$_selectedOnly',
                          ),
                          controller: widget.controller,
                          physics: const AlwaysScrollableScrollPhysics(),
                          cacheExtent: 200,
                          slivers: [
                            if (photos.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: state.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          state.error == null
                                              ? '이 사진첩에 사진이 없어요'
                                              : '사진을 불러오지 못했어요',
                                          style: ExperienceFormStyle.text(
                                            context,
                                            14,
                                            secondary: true,
                                          ),
                                        ),
                                ),
                              )
                            else
                              SliverLayoutBuilder(
                                builder: (context, constraints) => SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 2,
                                  ),
                                  sliver: SliverGrid(
                                    key: ValueKey(state.selectedAlbum?.id),
                                    gridDelegate:
                                        SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent:
                                              MediaQuery.orientationOf(
                                                    context,
                                                  ) ==
                                                  Orientation.landscape
                                              ? (constraints.viewportMainAxisExtent -
                                                        4)
                                                    .clamp(84, 138)
                                                    .toDouble()
                                              : 138,
                                          crossAxisSpacing: 3,
                                          mainAxisSpacing: 3,
                                        ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final asset = photos[index];
                                        final number =
                                            selectionOrder[asset.id] ?? 0;
                                        return Semantics(
                                          label: number > 0
                                              ? '사진 ${index + 1}, $number번째 선택'
                                              : '사진 ${index + 1}',
                                          selected: number > 0,
                                          button: true,
                                          child: InkWell(
                                            key: ValueKey(
                                              'gallery-photo-${asset.id}',
                                            ),
                                            onTap: () => _select(asset),
                                            child: RepaintBoundary(
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  GalleryThumbTile(
                                                    key: ValueKey(asset.id),
                                                    asset: asset,
                                                    simpleMode: true,
                                                    isSelected: false,
                                                  ),
                                                  if (number > 0)
                                                    Positioned.fill(
                                                      child: IgnorePointer(
                                                        child: DecoratedBox(
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  ExperienceFormStyle.selectionInk(
                                                                    context,
                                                                  ),
                                                              width: 2,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (number > 0)
                                                    Positioned(
                                                      top: 6,
                                                      right: 6,
                                                      child: CircleAvatar(
                                                        radius: 12,
                                                        backgroundColor:
                                                            ExperienceFormStyle.selectionInk(
                                                              context,
                                                            ),
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Text(
                                                            '$number',
                                                            maxLines: 1,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  SnapFitColors.isDark(
                                                                    context,
                                                                  )
                                                                  ? const Color(
                                                                      0xFF063740,
                                                                    )
                                                                  : Colors
                                                                        .white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      childCount: photos.length,
                                      addAutomaticKeepAlives: false,
                                    ),
                                  ),
                                ),
                              ),
                            if (!_selectedOnly &&
                                state.isLoading &&
                                state.images.isNotEmpty)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (state.error != null &&
                                !_selectedOnly &&
                                state.selectedAlbum != null)
                              SliverToBoxAdapter(
                                child: Center(
                                  child: TextButton.icon(
                                    onPressed: () => ref
                                        .read(galleryProvider.notifier)
                                        .loadMore(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('다시 불러오기'),
                                  ),
                                ),
                              ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (_multiple)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('confirm-gallery-selection'),
                    style: ExperienceFormStyle.primary(context),
                    onPressed: _selected.isEmpty
                        ? null
                        : () =>
                              Navigator.pop(context, _selected.values.toList()),
                    child: Text(
                      _selected.isEmpty ? '사진 선택' : '${_selected.length}장 가져오기',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GalleryAlbumSelectionSheet extends StatefulWidget {
  const _GalleryAlbumSelectionSheet({required this.state});
  final GalleryState state;

  @override
  State<_GalleryAlbumSelectionSheet> createState() =>
      _GalleryAlbumSelectionSheetState();
}

class _GalleryAlbumSelectionSheetState
    extends State<_GalleryAlbumSelectionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final albums = widget.state.albums
        .where(
          (album) => _albumName(
            album,
          ).toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList(growable: false);
    final scaler = MediaQuery.textScalerOf(context);
    final rowHeight = (scaler.scale(14) * 2 + scaler.scale(12) + 24).clamp(
      80,
      140,
    );
    final contentHeight =
        72 +
        rowHeight * widget.state.albums.length +
        (widget.state.albums.length > 8 ? 76 : 0) +
        MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: contentHeight
            .clamp(0, MediaQuery.sizeOf(context).height * .8)
            .toDouble(),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '사진첩',
                        style: ExperienceFormStyle.text(
                          context,
                          16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '사진첩 닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 22),
                    ),
                  ],
                ),
              ),
              if (widget.state.albums.length > 8)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    key: const ValueKey('gallery-album-search'),
                    style: ExperienceFormStyle.text(context, 14),
                    decoration: ExperienceFormStyle.input(
                      context,
                      hint: '사진첩 검색',
                    ).copyWith(prefixIcon: const Icon(Icons.search, size: 20)),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              Expanded(
                child: albums.isEmpty
                    ? Center(
                        child: Text(
                          '사진첩을 찾지 못했어요',
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            secondary: true,
                          ),
                        ),
                      )
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: albums.length,
                        itemBuilder: (context, index) {
                          final album = albums[index];
                          final selected =
                              widget.state.selectedAlbum?.id == album.id;
                          return _GalleryAlbumTile(
                            key: ValueKey('gallery-album-${album.id}'),
                            album: album,
                            selected: selected,
                            photo: selected
                                ? widget.state.images.firstOrNull
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryAlbumTile extends ConsumerStatefulWidget {
  const _GalleryAlbumTile({
    super.key,
    required this.album,
    required this.selected,
    this.photo,
  });
  final AssetPathEntity album;
  final AssetEntity? photo;
  final bool selected;

  @override
  ConsumerState<_GalleryAlbumTile> createState() => _GalleryAlbumTileState();
}

class _GalleryAlbumTileState extends ConsumerState<_GalleryAlbumTile> {
  late final Future<AssetEntity?> _photo = _loadPhoto();
  late final Future<int?> _count = _loadCount();

  Future<AssetEntity?> _loadPhoto() async {
    if (widget.photo != null) return widget.photo;
    try {
      return (await ref
              .read(galleryRepositoryProvider)
              .loadImagesPaged(widget.album, 0, 1))
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _loadCount() async {
    try {
      return await widget.album.assetCountAsync;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: SizedBox.square(
      dimension: 52,
      child: FutureBuilder<AssetEntity?>(
        future: _photo,
        builder: (context, snapshot) => snapshot.data == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: ExperienceFormStyle.surface(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 22,
                  color: ExperienceFormStyle.muted(context),
                ),
              )
            : GalleryThumbTile(
                asset: snapshot.data!,
                isSelected: false,
                simpleMode: true,
              ),
      ),
    ),
    title: Text(
      _albumName(widget.album),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: ExperienceFormStyle.text(
        context,
        14,
        weight: widget.selected ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
    subtitle: FutureBuilder<int?>(
      future: _count,
      builder: (context, snapshot) => snapshot.data == null
          ? const SizedBox.shrink()
          : Text(
              '${snapshot.data}장',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
    ),
    trailing: widget.selected
        ? Icon(
            Icons.check,
            size: 21,
            color: ExperienceFormStyle.selectionInk(context),
          )
        : null,
    onTap: () => Navigator.pop(context, widget.album),
  );
}
