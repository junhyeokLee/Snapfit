import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../core/utils/context_extensions.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../shared/web/web_design.dart';
import '../../domain/entities/album_page.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../providers/album_edit_session_provider.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/reader/album_reader_more_options_sheet.dart';
import '../widgets/reader/reader_page_gallery.dart';
import '../widgets/web/web_album_workspace.dart';
import 'page_editor_screen.dart';
import 'album_invite_screen.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

enum AlbumReaderInnerDetailAction { prepareBook }

class AlbumReaderInnerDetailScreen extends ConsumerStatefulWidget {
  const AlbumReaderInnerDetailScreen({
    super.key,
    required this.innerPages,
    required this.initialPageIndex,
    required this.singlePageW,
    required this.singlePageH,
    required this.interaction,
    required this.layerBuilder,
    this.onPageFocused,
  });
  final List<AlbumPage> innerPages;
  final int initialPageIndex;
  final double singlePageW, singlePageH;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final ValueChanged<String>? onPageFocused;
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

  void _notifyFocusedPage() {
    if (_current < 0 || _current >= _visible.length) return;
    final id = _visible[_current].id;
    if (id.isNotEmpty) widget.onPageFocused?.call(id);
  }

  void _selectPage(int index) {
    if (index < 0 || index >= _visible.length) return;
    setState(() => _current = index);
    _notifyFocusedPage();
  }

  Future<void> _editCurrentPage() async {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (vm.album?.allowsEditing == false || _visible.isEmpty) return;
    final viewedId = _visible[_current].id;
    final target = vm.pages.indexWhere((p) => p.id == viewedId);
    if (target < 1) return;
    final albumId = vm.album?.id;
    final albumOwner = vm.album?.userId;
    final session = vm.editSessionIdentity;
    final owner = ref.read(albumEditorOwnerReaderProvider)();
    await Navigator.push<bool>(
      context,
      snapFitRoute(page: PageEditorScreen(
          initialPageIndex: target,
          returnToPreviousOnSave: true,
        ), settings: albumId != null && albumId > 0
            ? WebAppRouteSettings(WebAppLocation(WebAppPage.editor, '$albumId'))
            : null),
    );
    if (!mounted) return;
    if (!identical(ref.read(albumEditorViewModelProvider.notifier), vm) ||
        !identical(vm.editSessionIdentity, session) ||
        vm.album?.id != albumId ||
        vm.album?.userId != albumOwner ||
        ref.read(albumEditorOwnerReaderProvider)() != owner) {
      return;
    }
    final updated = vm.pages.skip(1).toList();
    final retained = updated.indexWhere((p) => p.id == viewedId);
    final next = retained >= 0
        ? retained
        : _current.clamp(0, updated.isEmpty ? 0 : updated.length - 1);
    setState(() {
      _edited = updated;
      _current = next;
    });
    if (_pages.hasClients && updated.isNotEmpty) _pages.jumpToPage(next);
    _notifyFocusedPage();
  }

  void _inviteMembers() {
    final album = ref.read(albumEditorViewModelProvider.notifier).album;
    if (album == null || album.id <= 0 || !album.allowsManagement) return;
    Navigator.push(
      context,
      snapFitRoute(page: AlbumInviteScreen(
          album: album,
          albumId: album.id,
          albumTitle: album.title.isEmpty ? '스냅핏 앨범' : album.title,
        )),
    );
  }

  void _showMoreOptions() {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (vm.album?.allowsEditing == false) {
      context.showSnack('보기 전용 앨범이에요. 편집은 앨범 소유자에게 요청해 주세요.');
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
        Navigator.pop(context, AlbumReaderInnerDetailAction.prepareBook);
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
      onEdit: album?.allowsEditing == false || _visible.isEmpty
          ? null
          : () => _editCurrentPage(),
      onPageChanged: _selectPage,
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
    Widget rail({bool horizontal = false}) => WebAlbumPageRail(
      pages: _visible,
      selectedIndex: _current,
      cover: cover,
      theme: vm.selectedTheme,
      previewBuilder: previewBuilder,
      onSelected: _selectPage,
      horizontal: horizontal,
      includesCover: false,
    );
    return WebAlbumReaderWorkspace(
      title: album?.title.isNotEmpty == true ? album!.title : '앨범 상세',
      description:
          '${vm.selectedCover.displayName} · 내지 ${_visible.length}쪽'
          '${album?.allowsEditing == false ? ' · 보기 전용' : ''}',
      pageLabel: _visible.isEmpty
          ? '페이지 없음'
          : '내지 ${_current + 1} / ${_visible.length}쪽',
      pageRail: rail(),
      compactPageRail: rail(horizontal: true),
      onBack: () => Navigator.pop(context),
      backLabel: '앨범으로',
      editLabel: '현재 페이지 편집',
      onEdit: album?.allowsEditing == false || _visible.isEmpty
          ? null
          : _editCurrentPage,
      onPrevious: _current > 0 ? () => _selectPage(_current - 1) : null,
      onNext: _current + 1 < _visible.length
          ? () => _selectPage(_current + 1)
          : null,
      managementMenu: album?.allowsManagement == true
          ? IconButton(
              tooltip: '멤버 초대',
              onPressed: _inviteMembers,
              icon: const ExperienceIcon('UserPlus', size: 19),
            )
          : null,
      canvas: _visible.isEmpty
          ? const Center(child: Text('페이지가 없습니다.'))
          : Center(
              child: ReaderDetailPageArtwork(
                page: _visible[_current],
                ratio: ratio,
                interaction: previewInteraction,
                layerBuilder: previewBuilder,
                flatPresentation: true,
              ),
            ),
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
        boxShadow: flatPresentation
            ? const []
            : [
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
