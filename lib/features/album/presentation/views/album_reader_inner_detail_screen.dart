import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/web_app_location.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../shared/web/web_design.dart';
import '../../domain/entities/album_page.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/reader/album_reader_more_options_sheet.dart';
import '../widgets/reader/reader_page_gallery.dart';
import '../widgets/web/web_album_workspace.dart';
import 'page_editor_screen.dart';
import 'album_invite_screen.dart';

class AlbumReaderInnerDetailScreen extends ConsumerStatefulWidget {
  const AlbumReaderInnerDetailScreen({
    super.key,
    required this.innerPages,
    required this.initialPageIndex,
    required this.singlePageW,
    required this.singlePageH,
    required this.interaction,
    required this.layerBuilder,
  });
  final List<AlbumPage> innerPages;
  final int initialPageIndex;
  final double singlePageW, singlePageH;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  @override
  ConsumerState<AlbumReaderInnerDetailScreen> createState() =>
      _AlbumReaderInnerDetailScreenState();
}

class _AlbumReaderInnerDetailScreenState
    extends ConsumerState<AlbumReaderInnerDetailScreen> {
  late final PageController _pages;
  late int _current;
  List<AlbumPage>? _edited;
  List<AlbumPage> get _visible => _edited ?? widget.innerPages;
  @override
  void initState() {
    super.initState();
    _current = widget.initialPageIndex.clamp(
      0,
      widget.innerPages.isEmpty ? 0 : widget.innerPages.length - 1,
    );
    _pages = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _editCurrentPage() async {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (vm.album?.allowsEditing == false || _visible.isEmpty) return;
    final viewedId = _visible[_current].id;
    final target = vm.pages.indexWhere((p) => p.id == viewedId);
    if (target < 1) return;
    final albumId = vm.album?.id;
    await Navigator.push<bool>(context, MaterialPageRoute(
      settings: albumId != null && albumId > 0
          ? WebAppRouteSettings(WebAppLocation(WebAppPage.editor, '$albumId'))
          : null,
      builder: (_) => PageEditorScreen(
        initialPageIndex: target,
        returnToPreviousOnSave: true,
      ),
    ));
    if (!mounted) return;
    final updated = vm.pages.skip(1).toList();
    final retained = updated.indexWhere((p) => p.id == viewedId);
    final next = retained >= 0 ? retained
        : _current.clamp(0, updated.isEmpty ? 0 : updated.length - 1);
    setState(() {
      _edited = updated;
      _current = next;
    });
    if (_pages.hasClients && updated.isNotEmpty) _pages.jumpToPage(next);
  }

  void _inviteMembers() {
    final album = ref.read(albumEditorViewModelProvider.notifier).album;
    if (album == null || album.id <= 0 || !album.allowsManagement) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumInviteScreen(
      album: album,
      albumId: album.id,
      albumTitle: album.title.isEmpty ? '스냅핏 앨범' : album.title,
    )));
  }

  void _showMoreOptions() {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (vm.album?.allowsEditing == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보기 전용 앨범이에요. 편집은 앨범 소유자에게 요청해 주세요.')),
      );
      return;
    }
    Widget sheet(BuildContext ctx, bool compact) => AlbumReaderMoreOptionsSheet(
      compact: compact,
      onEdit: () async {
        Navigator.pop(ctx);
        await _editCurrentPage();
      },
      onConfirm: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('제작 확정은 메인 리더 화면에서 진행해주세요.')),
        );
      },
      onInvite: vm.album?.allowsManagement == false
          ? null
          : () {
              Navigator.pop(ctx);
              _inviteMembers();
            },
    );
    if (kIsWeb) {
      showWebAwareDialog<void>(
        context: context,
        maxWidth: 380,
        maxHeight: 520,
        builder: (ctx) => sheet(ctx, true),
      );
      return;
    }
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: SingleChildScrollView(child: sheet(ctx, true)),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) =>
            SafeArea(child: SingleChildScrollView(child: sheet(ctx, false))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(albumEditorViewModelProvider);
    final album = ref.read(albumEditorViewModelProvider.notifier).album;
    final rawRatio = widget.singlePageW / widget.singlePageH;
    final ratio = rawRatio.isFinite && rawRatio > 0 ? rawRatio : 1.0;
    if (kIsWeb) return _buildWebDetail(album, ratio);
    return ReaderPageGallery(
      title: album?.title ?? '앨범',
      controller: _pages,
      currentPage: _current,
      pageCount: _visible.length,
      onMore: _showMoreOptions,
      onPageChanged: (index) => setState(() => _current = index),
      pageBuilder: (context, index) => ReaderDetailPageArtwork(
        page: _visible[index],
        ratio: ratio,
        interaction: widget.interaction,
        layerBuilder: widget.layerBuilder,
      ),
    );
  }

  Widget _buildWebDetail(Album? album, double ratio) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final base = Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
    final previewInteraction = LayerInteractionManager.preview(ref, () => base);
    final previewBuilder = LayerBuilder(previewInteraction, () => base);
    final cover = CoverSize(
      name: vm.selectedCover.name,
      ratio: ratio,
      realSize: vm.selectedCover.realSize,
      productId: vm.selectedCover.productId,
    );
    void select(int index) {
      if (index < 0 || index >= _visible.length) return;
      setState(() => _current = index);
    }
    Widget rail({bool horizontal = false}) => WebAlbumPageRail(
      pages: _visible,
      selectedIndex: _current,
      cover: cover,
      theme: vm.selectedTheme,
      previewBuilder: previewBuilder,
      onSelected: select,
      horizontal: horizontal,
      includesCover: false,
    );
    final edit = OutlinedButton.icon(
      onPressed: album?.allowsEditing == false || _visible.isEmpty
          ? null : _editCurrentPage,
      icon: const Icon(Icons.edit_outlined, size: 17),
      label: const Text('현재 페이지 편집'),
    );
    final invite = album?.allowsManagement == true
        ? TextButton.icon(
            onPressed: _inviteMembers,
            icon: const Icon(Icons.group_add_outlined, size: 17),
            label: const Text('멤버 초대'),
          )
        : null;
    return SnapFitWebShell(
      title: '페이지 상세',
      workspace: true,
      showNavigation: false,
      actions: [TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: 17),
        label: const Text('앨범으로'),
      )],
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 1100;
        final compact = box.maxWidth < 760;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('문서 정보', style: TextStyle(
              color: WebPalette.of(context).ink, fontSize: 13, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 18),
            Text(vm.selectedCover.displayName, style: TextStyle(
              color: WebPalette.of(context).muted, fontSize: 12, height: 1.6,
            )),
            const SizedBox(height: 10),
            Text('내지 ${_visible.length}쪽', style: TextStyle(
              color: WebPalette.of(context).muted, fontSize: 12,
            )),
            const SizedBox(height: 10),
            Text(album?.allowsEditing == false ? '보기 전용' : '편집 가능',
              style: TextStyle(color: WebPalette.of(context).brandInk, fontSize: 12)),
            const SizedBox(height: 26),
            edit,
            if (invite != null) ...[const SizedBox(height: 10), invite],
            const SizedBox(height: 16),
            Text('책 주문은 앨범 미리보기 화면에서 전체 구성을 확인한 뒤 진행할 수 있습니다.',
              style: TextStyle(color: WebPalette.of(context).muted, fontSize: 12, height: 1.6)),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              color: WebPalette.of(context).surface,
              child: WebPageHeading(
                title: album?.title.isNotEmpty == true ? album!.title : '앨범 상세',
                eyebrow: 'PAGE DETAIL',
                description: '${vm.selectedCover.displayName} · 내지 ${_visible.length}쪽',
                trailing: wide ? null : Wrap(spacing: 10, runSpacing: 10,
                  children: [edit, if (invite != null) invite]),
              ),
            ),
            Divider(height: 1, color: WebPalette.of(context).line),
            if (compact) SizedBox(height: 112, child: rail(horizontal: true)),
            Expanded(child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compact) ...[
                  SizedBox(width: 166, child: rail()),
                  VerticalDivider(width: 1, color: WebPalette.of(context).line),
                ],
                Expanded(child: ColoredBox(
                  color: WebPalette.of(context).canvas,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '이전 페이지',
                            onPressed: _current > 0 ? () => select(_current - 1) : null,
                            icon: const Icon(Icons.chevron_left, size: 20),
                          ),
                          Text(_visible.isEmpty ? '페이지 없음'
                              : '${_current + 1} / ${_visible.length}',
                            style: TextStyle(color: WebPalette.of(context).ink, fontSize: 12)),
                          IconButton(
                            tooltip: '다음 페이지',
                            onPressed: _current + 1 < _visible.length
                                ? () => select(_current + 1) : null,
                            icon: const Icon(Icons.chevron_right, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      child: _visible.isEmpty ? const Center(child: Text('페이지가 없습니다.'))
                          : Center(child: ReaderDetailPageArtwork(
                              page: _visible[_current],
                              ratio: ratio,
                              interaction: previewInteraction,
                              layerBuilder: previewBuilder,
                              flatPresentation: true,
                            )),
                    )),
                  ]),
                )),
                if (wide) ...[
                  VerticalDivider(width: 1, color: WebPalette.of(context).line),
                  SizedBox(width: 264, child: ColoredBox(
                    color: WebPalette.of(context).surface,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24), child: details,
                    ),
                  )),
                ],
              ],
            )),
          ],
        );
      }),
    );
  }
}

class ReaderDetailPageArtwork extends StatelessWidget {
  const ReaderDetailPageArtwork({
    super.key,
    required this.page,
    required this.ratio,
    required this.interaction,
    required this.layerBuilder,
    this.flatPresentation = false,
  });
  final AlbumPage page;
  final double ratio;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final bool flatPresentation;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: ratio,
    child: DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: flatPresentation ? const [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRect(
        child: ColoredBox(
          color: Color(page.backgroundColor ?? 0xFFFFFFFF),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: kCoverReferenceWidth,
              height: kCoverReferenceWidth / ratio,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final layer in interaction.sortByZ(page.layers))
                    if (layer.type == LayerType.image ||
                        layer.type == LayerType.sticker ||
                        layer.type == LayerType.decoration)
                      layerBuilder.buildImage(layer)
                    else
                      layerBuilder.buildText(layer),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
