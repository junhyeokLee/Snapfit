import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../social/data/social_album_snapshot.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../domain/entities/album.dart';
import '../providers/album_edit_session_provider.dart';
import '../utils/album_progress.dart';
import '../utils/saved_album_experience.dart';
import '../widgets/home/home_album_actions.dart';

/// This screen owns a freshly read saved document. It never reads or mutates
/// the editor's global canvas, so a late save cannot display another book.
class AlbumSavedExperienceScreen extends ConsumerStatefulWidget {
  const AlbumSavedExperienceScreen({
    super.key,
    required this.albumId,
    required this.ownerId,
    this.reason = AlbumSavedReason.saved,
  });

  final int albumId;
  final String ownerId;
  final AlbumSavedReason reason;

  @override
  ConsumerState<AlbumSavedExperienceScreen> createState() =>
      _AlbumSavedExperienceScreenState();
}

class _AlbumSavedExperienceScreenState
    extends ConsumerState<AlbumSavedExperienceScreen> {
  final _pages = PageController();
  Album? _album;
  SocialAlbumSnapshot? _snapshot;
  AlbumProgressInfo? _progress;
  AlbumProgressRequest? _progressRequest;
  bool _loading = true, _exporting = false, _opening = false;
  bool _sessionChanged = false;
  int _selected = 0, _operation = 0;
  String? _error;

  bool get _current =>
      mounted &&
      !_sessionChanged &&
      ref.read(albumEditorOwnerReaderProvider)() == widget.ownerId;

  bool get _canResumeEditing =>
      _album?.allowsEditing == true &&
      _progress?.hasTarget == true &&
      _progress?.isCompleted == false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _operation++;
    _progressRequest?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _accountChanged(String? owner) {
    if (owner == widget.ownerId || _sessionChanged) return;
    _operation++;
    _progressRequest?.cancel();
    setState(() {
      _sessionChanged = true;
      _album = null;
      _snapshot = null;
      _loading = false;
      _exporting = false;
      _opening = false;
      _error = null;
    });
  }

  Future<void> _load() async {
    if (!_current) return;
    final operation = ++_operation;
    bool current() => _current && operation == _operation;
    setState(() {
      _loading = true;
      _exporting = false;
      _error = null;
      _album = null;
      _snapshot = null;
      _progress = null;
    });
    try {
      final album = await ref.read(savedAlbumLoaderProvider)(widget.albumId);
      if (!current()) return;
      final snapshot = SocialAlbumSnapshot.fromAlbum(album);
      _progressRequest?.cancel();
      final request = AlbumProgressLoader.request(album);
      _progressRequest = request;
      final progress = await request.result;
      if (!current()) return;
      setState(() {
        _album = album;
        _snapshot = snapshot;
        _progress = progress;
        _selected = 0;
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
    } catch (_) {
      if (current()) {
        setState(() => _error = '저장한 앨범을 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    final album = _album;
    final snapshot = _snapshot;
    if (!_current ||
        _loading ||
        _exporting ||
        _opening ||
        album == null ||
        snapshot == null)
      return;
    final selected = _selected;
    final operation = ++_operation;
    bool current() => _current && operation == _operation;
    final theme = Theme.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final load = ref.read(savedAlbumLoaderProvider);
      final fresh = await load(album.id);
      if (!current()) return;
      if (!isSameSavedAlbumRevision(album, fresh)) {
        await _load();
        if (_current) {
          setState(
            () => _error = '앨범이 새로 저장되었어요. 내용을 확인하고 공유할 페이지를 다시 골라 주세요.',
          );
        }
        return;
      }
      final render = ref.read(savedAlbumPageRendererProvider);
      final write = ref.read(savedAlbumImageWriterProvider);
      final bytes = await render(snapshot.pages[selected], theme);
      if (!current()) return;
      // Permission can be revoked while large photos are being decoded.
      final authorized = await load(album.id);
      if (!current()) return;
      if (!isSameSavedAlbumRevision(album, authorized)) {
        await _load();
        if (_current) {
          setState(() => _error = '앨범 내용이 바뀌었어요. 공유할 페이지를 다시 확인해 주세요.');
        }
        return;
      }
      await write(bytes, savedAlbumPageFileName(album.id, selected), origin);
    } catch (_) {
      if (current()) {
        setState(() => _error = '이미지를 준비하지 못했어요. 사진과 연결 상태를 확인한 뒤 다시 시도해 주세요.');
      }
    } finally {
      if (current()) setState(() => _exporting = false);
    }
  }

  Future<void> _open({bool publish = false}) async {
    final album = _album;
    if (!_current || album == null || _opening || _exporting) return;
    setState(() => _opening = true);
    try {
      final fresh = await ref.read(savedAlbumLoaderProvider)(album.id);
      if (!_current) return;
      if (publish) {
        if (fresh.userId != widget.ownerId || !fresh.allowsManagement) return;
        await HomeAlbumActions.onPublishSelected(context, ref, fresh);
      } else {
        await HomeAlbumActions.openAlbum(
          context,
          ref,
          fresh,
          canContinue: () => _current,
        );
        // The reader can edit, delete, or leave a shared album. Re-read its
        // saved state before showing the appreciation canvas again.
        if (_current) await _load();
      }
    } catch (_) {
      if (_current) setState(() => _error = '앨범을 열지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (_current) setState(() => _opening = false);
    }
  }

  Future<void> _resumeEditing() async {
    if (!_current ||
        _loading ||
        _opening ||
        _exporting ||
        !_canResumeEditing ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await HomeAlbumActions.onEditSelected(
        context,
        ref,
        _album!,
        startAtFirstIncompletePage: true,
        returnToPreviousOnSave: true,
        canContinue: () => _current,
        onEditorClosed: () {
          if (_current) unawaited(_load());
        },
      );
      // A revoked permission can stop preparation before a route is opened.
      if (_current && ModalRoute.of(context)?.isCurrent != false) await _load();
    } catch (_) {
      if (_current) setState(() => _error = '편집을 열지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (_current) setState(() => _opening = false);
    }
  }

  void _select(int index) {
    if (_exporting || _opening || !_pages.hasClients) return;
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(albumCurrentSessionOwnerProvider);
    ref.listen(
      albumCurrentSessionOwnerProvider,
      (_, next) => _accountChanged(next),
    );
    ref.listen<AsyncValue<String?>>(albumEditorOwnerChangesProvider, (_, next) {
      if (next.hasValue) _accountChanged(next.value);
    });
    final locked = _sessionChanged || owner != widget.ownerId;
    final colors = WebPalette.of(context);
    final snapshot = _snapshot;
    return SocialWebFrame(
      section: WebSection.albums,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('저장한 앨범'),
        ),
        bottomNavigationBar: locked || _loading || snapshot == null
            ? null
            : LayoutBuilder(
                builder: (context, bounds) {
                  if (bounds.maxWidth >= 850) return const SizedBox.shrink();
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(top: BorderSide(color: colors.line)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: _openButton(context),
                      ),
                    ),
                  );
                },
              ),
        body: locked
            ? Center(
                child: Text(
                  '계정이 변경되었어요. 내 앨범에서 다시 열어 주세요.',
                  style: TextStyle(color: colors.muted),
                ),
              )
            : _loading
            ? const Center(child: CircularProgressIndicator())
            : snapshot == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error ?? '앨범을 확인할 수 없어요.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('다시 불러오기'),
                      ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 850;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 32 : 20,
                      24,
                      wide ? 32 : 20,
                      40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: _gallery(context, snapshot),
                                  ),
                                  const SizedBox(width: 48),
                                  Expanded(flex: 4, child: _details(context)),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _details(context, headingOnly: true),
                                  const SizedBox(height: 16),
                                  _gallery(context, snapshot),
                                  const SizedBox(height: 28),
                                  _details(context, actionsOnly: true),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _gallery(BuildContext context, SocialAlbumSnapshot snapshot) {
    final colors = WebPalette.of(context);
    final selected = snapshot.pages[_selected];
    return LayoutBuilder(
      builder: (context, bounds) {
        final fittedHeight =
            math.max(0, bounds.maxWidth - 40) /
                selected.canvasSize.aspectRatio +
            40;
        final height = math
            .min(fittedHeight, MediaQuery.sizeOf(context).height * .58)
            .clamp(200.0, 560.0);
        return Column(
          children: [
            Container(
              key: const ValueKey('saved-album-gallery'),
              height: height,
              decoration: BoxDecoration(
                color: colors.canvas,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: PageView.builder(
                controller: _pages,
                physics: _exporting || _opening
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (index) => setState(() => _selected = index),
                itemCount: snapshot.pages.length,
                itemBuilder: (context, index) => Center(
                  child: AspectRatio(
                    aspectRatio: snapshot.pages[index].canvasSize.aspectRatio,
                    child: ClipRect(
                      child: SocialPublicationPagePreview(
                        page: snapshot.pages[index],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const ValueKey('saved-album-previous'),
                  tooltip: '이전 페이지',
                  onPressed: _selected > 0 && !_exporting && !_opening
                      ? () => _select(_selected - 1)
                      : null,
                  icon: const ExperienceIcon('ChevronLeft', size: 24),
                ),
                Text(
                  '${selected.isCover ? '표지' : '$_selected쪽'}  ·  ${_selected + 1}/${snapshot.pages.length}',
                  key: const ValueKey('saved-album-page-label'),
                  style: TextStyle(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  key: const ValueKey('saved-album-next'),
                  tooltip: '다음 페이지',
                  onPressed:
                      _selected < snapshot.pages.length - 1 &&
                          !_exporting &&
                          !_opening
                      ? () => _select(_selected + 1)
                      : null,
                  icon: const ExperienceIcon('ChevronRight', size: 24),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.pages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => Semantics(
                  selected: index == _selected,
                  button: true,
                  label: index == 0 ? '표지 선택' : '$index쪽 선택',
                  child: InkWell(
                    key: ValueKey('saved-album-thumbnail-$index'),
                    onTap: _exporting || _opening ? null : () => _select(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: index == _selected
                              ? colors.brand
                              : colors.line,
                          width: index == _selected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: SocialPublicationPagePreview(
                          page: snapshot.pages[index],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _openButton(BuildContext context) {
    final colors = WebPalette.of(context);
    return FilledButton.icon(
      key: const ValueKey('saved-album-open'),
      onPressed: _exporting || _opening ? null : () => _open(),
      style: FilledButton.styleFrom(
        backgroundColor: colors.brand,
        foregroundColor: SnapFitColors.onAccent,
        minimumSize: const Size.fromHeight(52),
      ),
      icon: const ExperienceIcon('BookOpen', size: 20),
      label: Text(_opening ? '앨범을 열고 있어요…' : '앨범 감상하기'),
    );
  }

  Widget _details(
    BuildContext context, {
    bool headingOnly = false,
    bool actionsOnly = false,
  }) {
    final colors = WebPalette.of(context);
    final complete = _progress?.isCompleted == true;
    final busy = _exporting || _opening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!actionsOnly) ...[
          Text(
            '앨범을 저장했어요',
            style: TextStyle(
              color: colors.brandInk,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _album!.title.trim().isEmpty ? '나의 앨범' : _album!.title,
            style: TextStyle(
              fontSize: 24,
              height: 1.25,
              letterSpacing: -.7,
              color: colors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_progress case final progress? when progress.hasTarget)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  complete
                      ? '${progress.targetPages}쪽 완성'
                      : '${progress.completedPages}/${progress.targetPages}쪽 작성',
                  style: TextStyle(fontSize: 13, color: colors.muted),
                ),
                if (_canResumeEditing)
                  TextButton.icon(
                    key: const ValueKey('saved-album-edit'),
                    onPressed: busy ? null : _resumeEditing,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.brandInk,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const ExperienceIcon('Pencil', size: 18),
                    label: const Text('이어서 편집'),
                  ),
              ],
            ),
        ],
        if (!headingOnly) ...[
          if (!actionsOnly) const SizedBox(height: 32),
          if (!actionsOnly) ...[
            _openButton(context),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            key: const ValueKey('saved-album-export'),
            onPressed: busy ? null : _export,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: colors.ink,
              side: BorderSide(color: colors.line),
            ),
            icon: const ExperienceIcon('Share2', size: 19),
            label: Text(
              _exporting
                  ? '선택한 페이지를 준비하고 있어요…'
                  : '${_selected == 0 ? '표지' : '$_selected쪽'} 이미지 저장·공유',
            ),
          ),
          if (_album!.userId == widget.ownerId && _album!.allowsManagement) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              key: const ValueKey('saved-album-publish'),
              onPressed: busy ? null : () => _open(publish: true),
              icon: const ExperienceIcon('Globe', size: 18),
              label: const Text('프로필에 앨범 공개'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              key: const ValueKey('saved-album-error'),
              style: TextStyle(color: colors.danger, height: 1.5),
            ),
          ],
        ],
      ],
    );
  }
}
