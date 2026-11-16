import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../album/data/api/album_provider.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import '../../data/social_album_snapshot.dart';
import '../../domain/social_models.dart';
import '../../domain/social_topics.dart';
import '../providers/social_providers.dart';
import '../social_actions.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_web_frame.dart';
import 'social_work_detail_screen.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

final socialPublishAlbumsProvider = FutureProvider.autoDispose<List<Album>>((
  ref,
) async {
  final owner = ref.watch(socialCurrentUserIdProvider);
  if (owner == null) return [];
  final albums = await ref.read(albumRepositoryProvider).fetchMyAlbums();
  if (ref.read(socialCurrentUserIdProvider) != owner) return [];
  return albums.where((a) => a.userId == owner).toList();
});

class SocialPublishScreen extends ConsumerStatefulWidget {
  const SocialPublishScreen({super.key, this.album});
  final Album? album;
  @override
  ConsumerState<SocialPublishScreen> createState() =>
      _SocialPublishScreenState();
}

class _SocialPublishScreenState extends ConsumerState<SocialPublishScreen> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final _selected = <int>[];
  String? _owner;
  Album? _album;
  SocialAlbumSnapshot? _snapshot;
  SocialPublicationDraft? _draft;
  SocialTemplateSource? _sourceTemplate;
  bool _includeSourceTemplate = false;
  bool _sourceLookupFailed = false;
  bool _sourceLookupBusy = false;
  String _requestId = const Uuid().v4();
  bool _requestAttempted = false;
  String _topic = '일상';
  String? _error;
  bool _loading = false,
      _publishing = false,
      _consent = false,
      _sessionChanged = false;
  int _step = 1, _completed = 0;
  int _pageOffset = 0, _reviewPage = 0;
  String _progress = '';
  int _loadRevision = 0;
  DialogRoute<bool>? _confirmation;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(socialCurrentUserIdProvider);
    if (widget.album != null) Future.microtask(() => _load(widget.album!));
  }

  @override
  void dispose() {
    _loadRevision++;
    _dismissConfirmation();
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  bool get _current =>
      mounted &&
      !_sessionChanged &&
      _owner != null &&
      ref.read(socialCurrentUserIdProvider) == _owner;

  Future<void> _load(Album source) async {
    if (!_current || _loading || _publishing || _confirmation != null) return;
    final revision = ++_loadRevision;
    bool current() => _current && revision == _loadRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Re-resolve the saved document. Never publish an editor's dirty state
      // or a compact home thumbnail document passed by a navigation entry.
      final fresh = await ref
          .read(albumRepositoryProvider)
          .fetchAlbum('${source.id}');
      if (!current()) return;
      if (fresh.userId != _owner)
        throw const FormatException('앨범 소유자만 앨범을 공개할 수 있어요.');
      final parsed = SocialAlbumSnapshot.fromAlbum(fresh);
      SocialTemplateSource? sourceTemplate;
      var sourceLookupFailed = false;
      if (fresh.sourceTemplateProductKey != null) {
        try {
          sourceTemplate = await ref
              .read(socialRepositoryProvider)
              .fetchAlbumTemplateSource(fresh.id);
        } catch (_) {
          // An unavailable catalog must not prevent a photo-only publication.
          sourceLookupFailed = true;
        }
        if (!current()) return;
      }
      setState(() {
        _album = fresh;
        _snapshot = parsed;
        _step = 1;
        _selected
          ..clear()
          ..addAll(
            List.generate(
              parsed.pages.length > 20 ? 20 : parsed.pages.length,
              (i) => i,
            ),
          );
        _title.text = fresh.title;
        _caption.clear();
        _consent = false;
        _sourceTemplate = sourceTemplate;
        _includeSourceTemplate = false;
        _sourceLookupFailed = sourceLookupFailed;
        _sourceLookupBusy = false;
        _draft = null;
        _requestAttempted = false;
        _pageOffset = 0;
        _reviewPage = 0;
        _requestId = const Uuid().v4();
      });
    } catch (error) {
      if (current())
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : '앨범을 불러오지 못했어요. 저장 상태를 확인하고 다시 시도해 주세요.',
        );
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    final source = _album, snapshot = _snapshot;
    if (!_current ||
        _publishing ||
        _confirmation != null ||
        source == null ||
        snapshot == null ||
        !_consent ||
        _selected.isEmpty ||
        _title.text.trim().isEmpty)
      return;
    setState(() {
      _publishing = true;
      _error = null;
      _completed = 0;
      _progress = '공개할 앨범을 준비하고 있어요.';
    });
    try {
      final repository = ref.read(socialRepositoryProvider);
      // Establish a separate public identity without copying private account
      // names or email addresses into a public profile.
      await repository.ensureOwnProfile();
      if (!_current) return;
      _requestAttempted = true;
      _draft = await repository.beginPublication(
        albumId: source.id,
        pageIndexes: List.of(_selected),
        title: _title.text,
        caption: _caption.text,
        topic: _topic,
        requestId: _requestId,
        expectedUpdatedAt: source.updatedAt,
        includeSourceTemplate: _includeSourceTemplate,
      );
      if (!_current) return;
      if (_draft!.status != 'draft') {
        final existing = await repository.fetchWork(_draft!.id);
        if (!_current) return;
        if (existing != null) {
          _finished(existing);
          return;
        }
        throw StateError('공개 결과를 확인할 수 없어요.');
      }
      final renderer = SocialSnapshotRenderer();
      await renderer.prepareFonts(
        _draft!.pageIndexes.map((index) => snapshot.pages[index]),
      );
      if (!_current) return;
      // Flush font-change notifications while the normal UI is still mounted.
      // The offscreen tree below contains synchronous, fully prepared artwork.
      await WidgetsBinding.instance.endOfFrame;
      if (!_current) return;
      final theme = Theme.of(context);
      for (
        var position = 0;
        position < _draft!.pageIndexes.length;
        position++
      ) {
        if (!_current) return;
        setState(
          () => _progress =
              '${position + 1} / ${_selected.length}쪽의 공개 이미지를 만들고 있어요.',
        );
        final bytes = await renderer.renderPage(
          snapshot.pages[_draft!.pageIndexes[position]],
          theme: theme,
        );
        if (!_current) return;
        await repository.uploadPublicationPage(_draft!.id, position, bytes);
        if (!_current) return;
        setState(() => _completed = position + 1);
      }
      if (!_current) return;
      setState(() => _progress = '모든 페이지를 확인하고 앨범을 공개하고 있어요.');
      final work = await repository.finalizePublication(_draft!.id);
      if (_current) _finished(work);
    } catch (error) {
      if (_current) setState(() => _error = _publicationError(error));
    } finally {
      if (_current) setState(() => _publishing = false);
    }
  }

  Future<void> _retryTemplateSource() async {
    final album = _album;
    if (!_current ||
        album == null ||
        _sourceLookupBusy ||
        _publishing ||
        _requestAttempted ||
        _draft != null)
      return;
    final revision = _loadRevision;
    bool current() =>
        _current && revision == _loadRevision && _album?.id == album.id;
    setState(() => _sourceLookupBusy = true);
    try {
      final source = await ref
          .read(socialRepositoryProvider)
          .fetchAlbumTemplateSource(album.id);
      if (!current()) return;
      if (source != null &&
          source.productKey != album.sourceTemplateProductKey) {
        setState(() => _error = '원본 앨범이 변경됐어요. 저장된 앨범을 다시 불러와 확인해 주세요.');
        return;
      }
      setState(() {
        _sourceTemplate = source;
        _sourceLookupFailed = false;
        _includeSourceTemplate = false;
      });
    } catch (_) {
      if (current()) setState(() => _sourceLookupFailed = true);
    } finally {
      if (current()) setState(() => _sourceLookupBusy = false);
    }
  }

  void _finished(SocialWork work) {
    invalidateSocial(ref, workId: work.id);
    Navigator.of(context).pushReplacement(
      snapFitRoute<void>(
        page: SocialWorkDetailScreen(workId: work.id),
        settings: WebAppRouteSettings(
          WebAppLocation(WebAppPage.socialWork, work.id),
        ),
      ),
    );
  }

  String _publicationError(Object error) {
    final code = error.toString();
    if (code.contains('source_changed'))
      return '원본 앨범이 변경됐어요. 저장된 앨범을 다시 불러와 공개할 내용을 확인해 주세요.';
    if (code.contains('source_template') || code.contains('template_source'))
      return '템플릿 이용 상태가 바뀌었어요. 앨범을 다시 불러온 뒤 템플릿 연결 여부를 확인해 주세요.';
    if (code.contains('collaborat') ||
        code.contains('shared_album') ||
        code.contains('members')) {
      return '함께 편집하는 앨범은 멤버 동의 기능을 준비한 뒤 공개할 수 있어요. 지금은 개인 앨범을 선택해 주세요.';
    }
    if (error is FormatException) return error.message.toString();
    if (code.contains('draft_limit'))
      return '완료하지 못한 공개가 남아 있어요. 미완료 공개를 정리한 뒤 다시 시도해 주세요.';
    return '공개를 완료하지 못했어요. 입력과 선택한 페이지는 유지돼요. 다시 시도해 주세요.';
  }

  Future<bool?> _confirm(WidgetBuilder builder) async {
    final route = DialogRoute<bool>(context: context, builder: builder);
    _confirmation = route;
    try {
      return await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      if (identical(_confirmation, route)) _confirmation = null;
    }
  }

  void _dismissConfirmation() {
    final route = _confirmation;
    _confirmation = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator != null && route.isActive) navigator.removeRoute(route);
    });
  }

  Future<void> _back() async {
    if (_sessionChanged) {
      Navigator.maybePop(context);
      return;
    }
    if (_publishing || _confirmation != null) return;
    if (_loading) {
      // Back cancels this selection, even if its saved document arrives later.
      _loadRevision++;
      setState(() => _loading = false);
    }
    final draft = _draft;
    if (draft != null) {
      // An interrupted finalize might already have committed. Resolve it before
      // enabling editing or a new publish request against the same draft.
      final discard = await _confirm(
        (context) => AlertDialog(
          title: const Text('공개 내용을 다시 확인할까요?'),
          content: const Text('게시 결과를 확인한 뒤 페이지와 소개를 다시 선택해요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('다시 확인'),
            ),
          ],
        ),
      );
      if (discard != true || !_current) return;
      setState(() {
        _publishing = true;
        _progress = '공개 결과를 확인하고 있어요.';
      });
      try {
        final repository = ref.read(socialRepositoryProvider);
        final discarded = await repository.discardPublication(draft.id);
        if (!_current) return;
        if (!discarded) {
          final existing = await repository.fetchWork(draft.id);
          if (!_current) return;
          if (existing == null) throw StateError('공개 결과를 확인할 수 없어요.');
          _finished(existing);
          return;
        }
        setState(() {
          _draft = null;
          _requestId = const Uuid().v4();
          _requestAttempted = false;
          _error = null;
          _step = 1;
          _consent = false;
        });
      } catch (_) {
        if (_current) socialError(context);
      } finally {
        if (_current) setState(() => _publishing = false);
      }
      return;
    }
    if (_step > 1) {
      setState(() {
        _step--;
        _consent = false;
        // A lost begin response can leave a private server draft while the
        // local ID is still null. Editing is a new request; unchanged retry
        // above deliberately retains the original key.
        if (_requestAttempted) {
          _requestId = const Uuid().v4();
          _requestAttempted = false;
        }
      });
      return;
    }
    if (_album != null) {
      setState(() {
        _album = null;
        _snapshot = null;
        _sourceTemplate = null;
        _includeSourceTemplate = false;
        _sourceLookupFailed = false;
        _sourceLookupBusy = false;
        _error = null;
      });
      return;
    }
    Navigator.maybePop(context);
  }

  Future<void> _discardUnfinished() async {
    if (!_current || _loading || _publishing || _confirmation != null) return;
    final confirm = await _confirm(
      (context) => AlertDialog(
        title: const Text('미완료 공개를 정리할까요?'),
        content: const Text(
          '다른 창에서 준비하던 미완료 공개도 취소돼요. 이미 공개한 앨범과 원본 앨범은 그대로 유지돼요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('미완료 공개 정리'),
          ),
        ],
      ),
    );
    if (confirm != true || !_current) return;
    setState(() {
      _publishing = true;
      _progress = '미완료 공개를 정리하고 있어요.';
    });
    try {
      await ref.read(socialRepositoryProvider).discardUnfinishedPublications();
      if (_current)
        setState(() {
          _draft = null;
          _requestId = const Uuid().v4();
          _requestAttempted = false;
          _error = null;
          _consent = false;
        });
    } catch (_) {
      if (_current) socialError(context);
    } finally {
      if (_current) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next && next != _owner && mounted)
        setState(() {
          _sessionChanged = true;
          _loadRevision++;
          _dismissConfirmation();
          _loading = false;
          _publishing = false;
          _snapshot = null;
          _album = null;
          _selected.clear();
          _title.clear();
          _caption.clear();
          _draft = null;
          _sourceTemplate = null;
          _includeSourceTemplate = false;
          _sourceLookupBusy = false;
        });
    });
    final user = ref.watch(socialCurrentUserIdProvider);
    return SocialWebFrame(
      child: PopScope(
        canPop: _sessionChanged || (!_publishing && _album == null),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_publishing) _back();
        },
        child: Scaffold(
          backgroundColor: SocialStyle.background(context),
          appBar: AppBar(
            title: Text(_album == null ? '공개할 앨범 선택' : '앨범 공개'),
            leading: IconButton(
              tooltip: '이전 단계',
              onPressed: _publishing && !_sessionChanged ? null : _back,
              icon: const ExperienceIcon('ArrowLeft'),
            ),
          ),
          body: SocialContent(
            child: _sessionChanged
                ? const SocialEmpty(
                    title: '계정이 변경됐어요.',
                    message: '내 앨범에서 공개할 앨범을 다시 선택해 주세요.',
                  )
                : user == null
                ? SocialEmpty(
                    title: '나의 기록을 나눠보세요.',
                    message: '로그인하면 기존 앨범에서 원하는 페이지만 공개할 수 있어요.',
                    action: FilledButton(
                      onPressed: () => requireSocialLogin(context, ref),
                      child: const Text('로그인'),
                    ),
                  )
                : _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _album == null
                ? _chooseAlbum()
                : _form(),
          ),
        ),
      ),
    );
  }

  Widget _chooseAlbum() {
    final albums = ref.watch(socialPublishAlbumsProvider);
    return albums.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => SocialFailure(
        onRetry: () => ref.invalidate(socialPublishAlbumsProvider),
      ),
      data: (items) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            '이미 만든 앨범에서\n새로운 이야기를 꺼내요.',
            style: TextStyle(
              fontSize: 25,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '전체나 마음에 드는 페이지만 프로필에 공개할 수 있어요.',
            style: TextStyle(height: 1.7),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const SocialEmpty(
              title: '아직 공개할 앨범이 없어요.',
              message: '내 앨범에서 개인 앨범을 저장한 뒤 다시 찾아주세요.',
            ),
          for (final album in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 72,
                  height: 86,
                  child: HomeAlbumCoverThumbnail(
                    album: album,
                    height: 86,
                    maxWidth: 72,
                    showShadow: false,
                  ),
                ),
                title: Text(album.title),
                subtitle: const Text('저장된 앨범에서 공개'),
                trailing: const ExperienceIcon('ChevronRight'),
                onTap: () => _load(album),
              ),
            ),
        ],
      ),
    );
  }

  Widget _form() => ListView(
    key: ValueKey('social-publish-form-$_step'),
    padding: const EdgeInsets.all(22),
    children: [
      Text(
        '$_step / 3 · ${_step == 1
            ? '공개할 페이지'
            : _step == 2
            ? '앨범 소개'
            : '최종 확인'}',
        style: TextStyle(color: SocialStyle.accent(context)),
      ),
      const SizedBox(height: 16),
      Text(
        _step == 1
            ? '어떤 장면을 나눌까요?'
            : _step == 2
            ? '기록에 이야기를 더해요.'
            : '이 내용으로 공개해요.',
        style: const TextStyle(
          fontSize: 24,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 12),
      if (_step == 1) ..._pageSelection(),
      if (_step == 2) ..._introduction(),
      if (_step == 3) ..._review(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(
                height: 1.7,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
      if (_error?.contains('원본 앨범이 변경') == true ||
          _error?.contains('템플릿 이용 상태가 바뀌') == true)
        OutlinedButton(
          onPressed: _publishing ? null : () => _load(_album!),
          child: const Text('저장된 앨범 다시 불러오기'),
        ),
      if (_error?.contains('완료하지 못한 공개가 남아') == true)
        OutlinedButton(
          onPressed: _publishing ? null : _discardUnfinished,
          child: const Text('미완료 공개 정리'),
        ),
      if (_publishing) ...[
        const SizedBox(height: 18),
        LinearProgressIndicator(
          value: _selected.isEmpty ? null : _completed / _selected.length,
        ),
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(_progress)),
      ],
      const SizedBox(height: 24),
      FilledButton(
        style: SocialStyle.primary(context),
        onPressed:
            _publishing ||
                _selected.isEmpty ||
                (_step >= 2 && _title.text.trim().isEmpty) ||
                (_step == 3 && !_consent)
            ? null
            : _step == 3
            ? _publish
            : () => setState(() {
                _step++;
                if (_step == 3) _reviewPage = _selected.first;
              }),
        child: Text(
          _publishing
              ? '앨범 공개 중…'
              : _step == 3
              ? '프로필에 앨범 공개'
              : '다음 · ${_selected.length}쪽',
        ),
      ),
      if (_step > 1)
        TextButton(
          onPressed: _publishing ? null : _back,
          child: const Text('이전 단계에서 다시 확인'),
        ),
      const SizedBox(height: 20),
      Text(
        '원본과 인쇄 확정 상태는 바뀌지 않아요. 공개 후 원본을 편집해도 이 앨범은 자동으로 바뀌지 않아요.',
        style: TextStyle(
          fontSize: 12,
          height: 1.8,
          color: SnapFitColors.textSecondaryOf(context),
        ),
      ),
    ],
  );

  List<Widget> _pageSelection() => [
    const Text(
      '최대 20쪽까지 공개할 수 있어요. 선택한 순서의 첫 페이지가 대표 이미지가 돼요.',
      style: TextStyle(height: 1.7),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: _snapshot!.pages.length > 20
              ? null
              : () => setState(() {
                  _selected
                    ..clear()
                    ..addAll(List.generate(_snapshot!.pages.length, (i) => i));
                }),
          child: const Text('전체 선택'),
        ),
        TextButton(
          onPressed: () => setState(_selected.clear),
          child: const Text('선택 지우기'),
        ),
      ],
    ),
    const SizedBox(height: 16),
    GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: (_snapshot!.pages.length - _pageOffset).clamp(0, 6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, position) {
        final index = _pageOffset + position;
        final selected = _selected.contains(index);
        return InkWell(
          onTap: () => setState(() {
            if (selected) {
              _selected.remove(index);
            } else if (_selected.length < 20) {
              _selected.add(index);
            } else {
              socialError(context, message: '한 앨범에 최대 20쪽까지 공개할 수 있어요.');
            }
          }),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? SocialStyle.accent(context)
                    : Theme.of(context).dividerColor,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SocialPublicationPagePreview(
                        page: _snapshot!.pages[index],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          index == 0 ? '표지' : '$index쪽',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        size: 20,
                        color: selected ? SocialStyle.accent(context) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    if (_snapshot!.pages.length > 6)
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: '이전 페이지 목록',
            onPressed: _pageOffset == 0
                ? null
                : () => setState(() => _pageOffset -= 6),
            icon: const ExperienceIcon('ChevronLeft'),
          ),
          Text(
            '${_pageOffset + 1}–${(_pageOffset + 6).clamp(0, _snapshot!.pages.length)} / ${_snapshot!.pages.length}쪽',
          ),
          IconButton(
            tooltip: '다음 페이지 목록',
            onPressed: _pageOffset + 6 >= _snapshot!.pages.length
                ? null
                : () => setState(() => _pageOffset += 6),
            icon: const ExperienceIcon('ChevronRight'),
          ),
        ],
      ),
  ];

  List<Widget> _introduction() => [
    TextField(
      controller: _title,
      maxLength: 80,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(labelText: '공개 앨범 제목'),
    ),
    const SizedBox(height: 18),
    TextField(
      controller: _caption,
      maxLength: 500,
      minLines: 3,
      maxLines: 6,
      decoration: const InputDecoration(
        labelText: '앨범 소개',
        hintText: '이 앨범에 담긴 이야기를 나눠주세요.',
      ),
    ),
    const SizedBox(height: 18),
    const Text('주제'),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final topic in socialTopicLabels)
          ChoiceChip(
            label: Text(topic),
            selected: _topic == topic,
            onSelected: (_) => setState(() => _topic = topic),
          ),
      ],
    ),
    const SizedBox(height: 22),
    if (_sourceTemplate != null) ...[
      Material(
        color: SocialStyle.paper(context),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: SocialStyle.line(context)),
        ),
        child: CheckboxListTile(
          key: const ValueKey('social-publish-template-consent'),
          value: _includeSourceTemplate,
          onChanged: _publishing || _requestAttempted || _draft != null
              ? null
              : (value) =>
                    setState(() => _includeSourceTemplate = value ?? false),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('사용한 템플릿도 소개하기'),
          subtitle: Text(
            '${_sourceTemplate!.title}\n앨범을 본 사람이 이 공식 템플릿으로 자신의 앨범을 시작할 수 있어요. 내 사진과 글은 가져가지 않아요. 유료 템플릿은 별도 구매가 필요해요.',
            style: const TextStyle(height: 1.7),
          ),
        ),
      ),
      const SizedBox(height: 22),
    ] else if (_sourceLookupFailed) ...[
      const Text(
        '사용한 템플릿을 확인하지 못했어요. 앨범은 그대로 공개할 수 있어요.',
        style: TextStyle(height: 1.7),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('social-publish-template-retry'),
          onPressed: _publishing || _sourceLookupBusy || _requestAttempted
              ? null
              : _retryTemplateSource,
          child: Text(_sourceLookupBusy ? '템플릿 확인 중…' : '템플릿 다시 확인'),
        ),
      ),
      const SizedBox(height: 12),
    ],
    const Text(
      '앨범 공개와 감상은 무료예요. 선택한 사진과 문구가 보이는 감상용 페이지를 공개하며, 편집 가능한 원본은 공유하지 않아요.',
      style: TextStyle(height: 1.8),
    ),
  ];

  List<Widget> _review() {
    if (_selected.isEmpty) return const [];
    final pageIndex = _selected.contains(_reviewPage)
        ? _reviewPage
        : _selected.first;
    final position = _selected.indexOf(pageIndex);
    final reorderable = !_publishing && !_requestAttempted && _draft == null;
    return [
      Text(
        _title.text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
      if (_caption.text.trim().isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(_caption.text, style: const TextStyle(height: 1.8)),
      ],
      const SizedBox(height: 12),
      Text('$_topic · ${_selected.length}쪽 공개'),
      if (_includeSourceTemplate && _sourceTemplate != null) ...[
        const SizedBox(height: 12),
        Text(
          '함께 소개할 템플릿 · ${_sourceTemplate!.title}',
          key: const ValueKey('social-publish-template-review'),
          style: TextStyle(color: SocialStyle.accent(context), height: 1.7),
        ),
      ],
      const SizedBox(height: 18),
      SizedBox(
        height: (MediaQuery.sizeOf(context).height * .35)
            .clamp(180.0, 300.0)
            .toDouble(),
        child: Center(
          child: SocialPublicationPagePreview(
            key: const ValueKey('social-publish-review-stage'),
            page: _snapshot!.pages[pageIndex],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Text(
              '${position == 0 ? '대표 페이지' : '${position + 1}번째 공개 페이지'} · ${pageIndex == 0 ? '표지' : '$pageIndex쪽'}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (reorderable && _selected.length > 1) ...[
            const Text('순서', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '공개 순서 앞으로',
              onPressed: position == 0 ? null : () => _reorder(position, -1),
              icon: const ExperienceIcon('ChevronLeft'),
            ),
            IconButton(
              tooltip: '공개 순서 뒤로',
              onPressed: position == _selected.length - 1
                  ? null
                  : () => _reorder(position, 1),
              icon: const ExperienceIcon('ChevronRight'),
            ),
          ],
        ],
      ),
      if (_selected.length > 1) ...[
        const SizedBox(height: 8),
        SizedBox(
          key: const ValueKey('social-publish-review-pages'),
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            cacheExtent: 0,
            itemCount: _selected.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, item) {
              final index = _selected[item];
              final focused = index == pageIndex;
              void selectPage() {
                if (!_current || _publishing || !_selected.contains(index))
                  return;
                setState(() => _reviewPage = index);
              }

              return Semantics(
                button: true,
                selected: focused,
                onTap: _publishing ? null : selectPage,
                label:
                    '${item + 1}번째 공개 페이지, ${index == 0 ? '표지' : '$index쪽'}${item == 0 ? ', 대표 페이지' : ''}',
                excludeSemantics: true,
                child: SizedBox(
                  width: 72,
                  child: Material(
                    color: focused
                        ? SocialStyle.paper(context)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: focused
                            ? SocialStyle.accent(context)
                            : SocialStyle.line(context),
                        width: focused ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('social-publish-review-page-$index'),
                      onTap: _publishing ? null : selectPage,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: SocialPublicationPagePreview(
                                  page: _snapshot!.pages[index],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item == 0 ? '대표' : '${item + 1}번째',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: focused
                                    ? SocialStyle.accent(context)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      const SizedBox(height: 18),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _consent,
        onChanged: _publishing
            ? null
            : (value) => setState(() => _consent = value ?? false),
        title: const Text('선택한 사진과 문구를 누구나 볼 수 있도록 공개하는 내용을 확인했어요.'),
        subtitle: const Text('개인정보와 함께 등장한 사람의 공개 의사를 확인해 주세요.'),
      ),
    ];
  }

  void _reorder(int position, int offset) {
    if (!_current ||
        _publishing ||
        _requestAttempted ||
        _draft != null ||
        position < 0 ||
        position >= _selected.length ||
        position + offset < 0 ||
        position + offset >= _selected.length)
      return;
    setState(() {
      final item = _selected.removeAt(position);
      _selected.insert(position + offset, item);
      // 순서와 대표 페이지가 바뀌면 바뀐 공개 내용을 다시 확인한다.
      _consent = false;
    });
  }
}
