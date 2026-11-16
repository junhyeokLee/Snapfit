import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/context_extensions.dart';

import '../../../../core/fonts/document_fonts.dart';
import '../widgets/moment_document_font_entry.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../../store/presentation/widgets/template_page_renderer.dart';
import '../../domain/moment_record.dart';
import '../../domain/monthly_album_builder.dart';
import '../../data/moment_engagement_repository.dart';
import '../providers/moment_engagement_providers.dart';
import '../providers/moments_providers.dart';
import '../providers/private_moment_archive_providers.dart';
import '../widgets/moments_widgets.dart';
import '../../../../shared/widgets/experience_icon.dart';

class MonthlyMomentPreviewScreen extends ConsumerStatefulWidget {
  final bool _fontsPrepared;

  const MonthlyMomentPreviewScreen({
    super.key,
    required this.month,
    required this.records,
    this.today,
    this.existingAlbumId,
    this.importedPhotoIds = const [],
    this.onAlbumCreated,
  }) : _fontsPrepared = false;
  final DateTime month;
  final List<MomentRecord> records;
  final DateTime? today;
  final int? existingAlbumId;
  final List<String> importedPhotoIds;
  final Future<void> Function(Album)? onAlbumCreated;

  MonthlyMomentPreviewScreen._withFontsReady(
    MonthlyMomentPreviewScreen original,
  ) : _fontsPrepared = true,
      month = original.month,
      records = original.records,
      today = original.today,
      existingAlbumId = original.existingAlbumId,
      importedPhotoIds = original.importedPhotoIds,
      onAlbumCreated = original.onAlbumCreated;

  @override
  ConsumerState<MonthlyMomentPreviewScreen> createState() =>
      // ignore: no_logic_in_create_state — intentional: selects a different State subtype for deferred font loading
      DocumentFonts.deferred && !_fontsPrepared
      ? MomentDocumentFontEntryState<MonthlyMomentPreviewScreen>(
          MonthlyMomentPreviewScreen._withFontsReady,
        )
      : _MonthlyMomentPreviewScreenState();
}

class _MonthlyMomentPreviewScreenState
    extends ConsumerState<MonthlyMomentPreviewScreen> {
  late final TextEditingController _title;
  final PageController _pages = PageController();
  final List<String> _selected = [];
  final Map<String, MomentPhoto> _photos = {};
  final Map<String, DateTime> _dates = {};
  final Set<String> _imported = {};
  List<({Color color, List<LayerModel> layers})> _preview = [];
  int _page = 0, _identity = 0;
  int _savedPageCount = 0, _pendingPageCount = 0;
  bool _busy = false, _sessionChanged = false, _loadingAlbum = false;
  String? _owner, _error, _previewError;
  Album? _createdAlbum;
  Album? _existingAlbum;
  StreamSubscription<String?>? _authChanges;
  StreamSubscription<int>? _archiveSession;
  ProviderSubscription<AsyncValue<List<String>>>? _choiceSubscription;
  int _candidateGeneration = 0, _choiceEditRevision = 0;
  bool _loadingCandidates = false, _candidateOrderApplied = false;
  String? _candidateError;
  List<String> _candidateChoices = const [];

  bool get _existing => widget.existingAlbumId != null;
  Size get _previewCanvas => _existingAlbum == null
      ? monthlyMomentCanvasSize
      : coverCanvasBaseSize(_existingAlbum!.physicalCoverSize);

  @override
  void initState() {
    super.initState();
    _owner = ref.read(momentsCurrentUserIdProvider);
    _authChanges = ref.read(momentsRepositoryProvider).authChanges.listen((
      owner,
    ) {
      if (owner != _owner) _lockSession();
    }, onError: (Object _, StackTrace __) => _lockSession());
    _imported.addAll(widget.importedPhotoIds);
    _title = TextEditingController(
      text: '${widget.month.year}년 ${widget.month.month}월의 순간들',
    );
    _refreshAvailablePhotos();
    _selected.addAll(
      selectMonthlyMomentPhotoIds(
        month: widget.month,
        records: [
          for (final record in widget.records)
            record.withPhotos(
              record.photos
                  .where((photo) => _photos.containsKey(photo.id))
                  .toList(),
            ),
        ],
      ),
    );
    if (_existing) {
      _loadExisting();
    } else {
      _rebuildPreview();
    }
    unawaited(_loadCandidateChoices());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final owner = _owner;
      if (owner == null || !_current(owner, _identity)) return;
      try {
        unawaited(
          ref
              .read(momentEngagementRepositoryProvider)
              .recordActivity(
                MomentActivity.monthlyPreviewed,
                month: widget.month,
              ),
        );
      } catch (_) {
        // Optional measurement cannot interrupt a private album preview.
      }
    });
  }

  void _lockSession() {
    if (!mounted || _sessionChanged) return;
    setState(() {
      _identity++;
      _candidateGeneration++;
      _choiceSubscription?.close();
      _choiceSubscription = null;
      _sessionChanged = true;
      _busy = false;
      _photos.clear();
      _dates.clear();
      _selected.clear();
      _candidateChoices = const [];
      _candidateError = null;
      _loadingCandidates = false;
      _preview = [];
      _savedPageCount = 0;
      _pendingPageCount = 0;
      _previewError = null;
      _title.clear();
      _createdAlbum = null;
      _existingAlbum = null;
      _imported.clear();
      _error = null;
    });
  }

  Future<void> _loadCandidateChoices({bool refresh = false}) async {
    final owner = _owner;
    if (owner == null || _sessionChanged) return;
    final identity = _identity;
    final generation = ++_candidateGeneration;
    final edited = _choiceEditRevision;
    final month = momentMonth(widget.month);
    setState(() {
      _loadingCandidates = true;
      _candidateError = null;
    });
    bool current() =>
        _current(owner, identity) &&
        generation == _candidateGeneration &&
        month == momentMonth(widget.month);
    try {
      final archive = ref.read(privateMomentArchiveRepositoryProvider);
      _archiveSession ??= archive.sessionChanges.listen(
        (_) => _lockSession(),
        onError: (Object _, StackTrace __) => _lockSession(),
      );
      final session = archive.sessionRevision;
      final query = MomentPhotoChoicesQuery(owner, month);
      _choiceSubscription?.close();
      _choiceSubscription = ref.listenManual(
        monthlyMomentPhotoChoicesProvider(query),
        (_, __) {},
      );
      final choices = await (refresh
          ? ref.refresh(monthlyMomentPhotoChoicesProvider(query).future)
          : ref.read(monthlyMomentPhotoChoicesProvider(query).future));
      if (!current() || archive.sessionRevision != session) return;
      setState(() {
        _candidateChoices = choices.where(_photos.containsKey).toSet().toList();
        // Initial suggestions are subordinate to the owner's edits. A late
        // response must never replace a photo/cover selection already changed.
        if (edited == 0 &&
            _choiceEditRevision == 0 &&
            !_busy &&
            _createdAlbum == null) {
          _candidateOrderApplied = true;
          final selected = <String>{..._candidateChoices, ..._selected};
          _selected
            ..clear()
            ..addAll(selected.take(9));
          _rebuildPreview();
        }
        _loadingCandidates = false;
      });
    } catch (_) {
      if (current())
        setState(() {
          _loadingCandidates = false;
          _candidateError = '고른 후보를 불러오지 못했어요. 사진은 직접 고를 수 있어요.';
        });
    }
  }

  List<MomentPhoto> get _orderedPhotos => !_candidateOrderApplied
      ? _photos.values.toList()
      : [
          for (final id in _candidateChoices)
            if (_photos[id] case final MomentPhoto photo) photo,
          for (final entry in _photos.entries)
            if (!_candidateChoices.contains(entry.key)) entry.value,
        ];

  void _refreshAvailablePhotos() {
    _photos.clear();
    _dates.clear();
    for (final record in widget.records) {
      if (momentMonth(record.recordDate) != momentMonth(widget.month)) continue;
      for (final photo in record.photos) {
        if (_existing && _imported.contains(photo.id)) continue;
        if (_photos.containsKey(photo.id)) continue;
        _photos[photo.id] = photo;
        _dates[photo.id] = record.recordDate;
      }
    }
    _selected.removeWhere((id) => !_photos.containsKey(id));
    _candidateChoices = _candidateChoices.where(_photos.containsKey).toList();
  }

  @override
  void didUpdateWidget(covariant MonthlyMomentPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sessionChanged) return;
    // A reused route must not accept an old album response for its new month.
    if (oldWidget.existingAlbumId != widget.existingAlbumId ||
        momentMonth(oldWidget.month) != momentMonth(widget.month)) {
      _identity++;
      _candidateGeneration++;
      _choiceEditRevision = 0;
      _candidateOrderApplied = false;
      _candidateChoices = const [];
      _candidateError = null;
      _busy = false;
      _loadingAlbum = false;
      _existingAlbum = null;
      _createdAlbum = null;
      _selected.clear();
      _imported.clear();
      _page = 0;
      _error = null;
      _title.text = '${widget.month.year}년 ${widget.month.month}월의 순간들';
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
    _imported.addAll(widget.importedPhotoIds);
    _refreshAvailablePhotos();
    _rebuildPreview();
    if (_existing && _existingAlbum == null) _loadExisting();
    if (oldWidget.existingAlbumId != widget.existingAlbumId ||
        momentMonth(oldWidget.month) != momentMonth(widget.month)) {
      unawaited(_loadCandidateChoices());
    }
  }

  @override
  void dispose() {
    _identity++;
    _candidateGeneration++;
    _choiceSubscription?.close();
    unawaited(_authChanges?.cancel());
    unawaited(_archiveSession?.cancel());
    _title.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _rebuildPreview() {
    _previewError = null;
    if (_existing) {
      _preview = _decodePages(_existingAlbum?.coverLayersJson ?? '');
      _savedPageCount = _preview.length;
      _pendingPageCount = 0;
      _previewError = null;
      final album = _existingAlbum;
      if (album != null) {
        try {
          final plan = buildMonthlyMomentAppendPreview(
            existingDocumentJson: album.coverLayersJson,
            month: widget.month,
            records: widget.records,
            selectedPhotoIds: _selected,
            canvasSize: _previewCanvas,
          );
          final decoded = _decodePageValues(plan.pages);
          if (decoded.length != plan.pages.length) {
            throw StateError('The saved page cannot be displayed');
          }
          _preview = decoded;
          _savedPageCount = plan.existingPages.length;
          _pendingPageCount = plan.pendingPages.length;
        } catch (error) {
          _previewError = error is ArgumentError && error.message is String
              ? error.message as String
              : '추가할 페이지를 미리 보지 못했어요. 사진을 다시 골라 주세요.';
        }
      }
      _clampPreviewPage();
      return;
    }
    if (_selected.isEmpty) {
      _preview = [];
      _page = 0;
      return;
    }
    try {
      final draft = buildMonthlyMomentAlbum(
        month: widget.month,
        records: widget.records,
        selectedPhotoIds: _selected,
        title: _title.text.trim(),
      );
      final document =
          jsonDecode(draft.coverLayersJson) as Map<String, dynamic>;
      _preview = (document['pages'] as List).map((value) {
        final page = Map<String, dynamic>.from(value as Map);
        return (
          color: Color((page['backgroundColor'] as num).toInt()),
          layers: (page['layers'] as List)
              .map(
                (layer) => LayerExportMapper.fromJson(
                  Map<String, dynamic>.from(layer as Map),
                  canvasSize: monthlyMomentCanvasSize,
                  isCover: page['isCover'] == true,
                ),
              )
              .toList(),
        );
      }).toList();
      if (_page >= _preview.length) {
        _page = 0;
        if (_pages.hasClients) _pages.jumpToPage(0);
      }
    } catch (_) {
      _preview = [];
      _page = 0;
    }
  }

  List<({Color color, List<LayerModel> layers})> _decodePages(String json) {
    try {
      final document = jsonDecode(json) as Map;
      return _decodePageValues(document['pages'] as List);
    } catch (_) {
      return [];
    }
  }

  List<({Color color, List<LayerModel> layers})> _decodePageValues(
    Iterable<dynamic> values,
  ) => values.map((value) {
    final page = Map<String, dynamic>.from(value as Map);
    return (
      color: Color((page['backgroundColor'] as num?)?.toInt() ?? 0xFFFAF8F1),
      layers: (page['layers'] as List)
          .map(
            (layer) => LayerExportMapper.fromJson(
              Map<String, dynamic>.from(layer as Map),
              canvasSize: _previewCanvas,
              isCover: page['isCover'] == true,
            ),
          )
          .toList(),
    );
  }).toList();

  void _clampPreviewPage() {
    final next = _preview.isEmpty ? 0 : _page.clamp(0, _preview.length - 1);
    if (next == _page) return;
    _page = next;
    final identity = _identity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identity == _identity && _pages.hasClients) {
        _pages.jumpToPage(_page);
      }
    });
  }

  void _showPreviewPage(int page) {
    if (!_pages.hasClients || page >= _preview.length) return;
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _checkExistingAlbum(Album album, String owner) {
    if (album.id != widget.existingAlbumId || album.userId != owner) {
      throw const MomentException('이 앨범을 열 수 없어요. 나의 기록에서 다시 시작해 주세요.');
    }
  }

  Future<void> _loadExisting() async {
    final owner = _owner;
    if (owner == null || _sessionChanged || _loadingAlbum) return;
    final identity = _identity;
    setState(() {
      _loadingAlbum = true;
      _error = null;
    });
    try {
      final album = await ref
          .read(momentsRepositoryProvider)
          .fetchAlbum(widget.existingAlbumId!);
      if (!_current(owner, identity)) return;
      _checkExistingAlbum(album, owner);
      setState(() {
        _existingAlbum = album;
        _title.text = album.title;
        _rebuildPreview();
      });
    } catch (error) {
      if (_current(owner, identity))
        setState(
          () => _error = error is MomentException
              ? error.message
              : '저장한 앨범을 불러오지 못했어요. 다시 시도해 주세요.',
        );
    } finally {
      if (_current(owner, identity)) setState(() => _loadingAlbum = false);
    }
  }

  void _toggle(String id) {
    if (_busy || (!_existing && _createdAlbum != null) || _sessionChanged)
      return;
    if (!_selected.contains(id) && _selected.length >= 9) {
      context.showSnack(
        _existing ? '한 번에 아홉 장까지 더 담을 수 있어요.' : '월간 앨범에는 사진을 아홉 장까지 담을 수 있어요.',
      );
      return;
    }
    setState(() {
      _choiceEditRevision++;
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      _error = null;
      _rebuildPreview();
    });
  }

  void _cover(String id) {
    if (_existing || _busy || _createdAlbum != null || !_selected.contains(id))
      return;
    setState(() {
      _choiceEditRevision++;
      _selected.remove(id);
      _selected.insert(0, id);
      _rebuildPreview();
      _page = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    });
  }

  bool _current(String owner, int identity) =>
      mounted &&
      !_sessionChanged &&
      identity == _identity &&
      owner == ref.read(momentsCurrentUserIdProvider);

  Future<void> _create() async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (_busy || _sessionChanged || owner == null || owner != _owner) return;
    if (_selected.isEmpty) {
      setState(() => _error = '앨범에 담을 사진을 한 장 이상 골라 주세요.');
      return;
    }
    final identity = _identity;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(momentsRepositoryProvider);
      final album = _createdAlbum != null
          ? await repository.fetchAlbum(_createdAlbum!.id)
          : await repository.createMonthlyAlbum(
              month: widget.month,
              selectedRecords: widget.records,
              selectedPhotoIds: List.of(_selected),
              title: _title.text.trim().isEmpty
                  ? '${widget.month.year}년 ${widget.month.month}월의 순간들'
                  : _title.text.trim(),
            );
      if (!_current(owner, identity)) return;
      setState(() => _createdAlbum = album);
      ref.invalidate(momentsMonthProvider);
      if (widget.onAlbumCreated != null) {
        await widget.onAlbumCreated!(album);
      }
    } catch (error) {
      if (_current(owner, identity))
        setState(
          () => _error = _createdAlbum != null
              ? '앨범은 저장됐어요. 편집 화면을 다시 열어 주세요.'
              : error is MomentException
              ? error.message
              : '앨범을 만들지 못했어요. 고른 사진은 그대로 있으니 다시 시도해 주세요.',
        );
    } finally {
      if (_current(owner, identity)) setState(() => _busy = false);
    }
  }

  Future<void> _existingAction({required bool append}) async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (!_existing ||
        _busy ||
        _loadingAlbum ||
        _sessionChanged ||
        owner == null ||
        owner != _owner ||
        _existingAlbum == null)
      return;
    if (append && (_selected.isEmpty || _previewError != null)) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final identity = _identity;
    final chosen = List<String>.of(_selected);
    var photosAdded = false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(momentsRepositoryProvider);
      final album = append
          ? await repository.appendMonthlyAlbum(
              month: widget.month,
              selectedRecords: widget.records,
              selectedPhotoIds: chosen,
            )
          : await repository.fetchAlbum(widget.existingAlbumId!);
      if (!_current(owner, identity)) return;
      _checkExistingAlbum(album, owner);
      photosAdded = append;
      setState(() {
        _existingAlbum = album;
        _title.text = album.title;
        if (append) {
          _imported.addAll(chosen);
          for (final id in chosen) {
            _photos.remove(id);
            _dates.remove(id);
          }
          _selected.clear();
        }
        _rebuildPreview();
      });
      ref.invalidate(momentsMonthProvider);
      if (widget.onAlbumCreated != null &&
          ModalRoute.of(context)?.isCurrent != false) {
        await widget.onAlbumCreated!(album);
        if (!_current(owner, identity)) return;
        final refreshed = await repository.fetchAlbum(widget.existingAlbumId!);
        if (!_current(owner, identity)) return;
        _checkExistingAlbum(refreshed, owner);
        setState(() {
          _existingAlbum = refreshed;
          _title.text = refreshed.title;
          _rebuildPreview();
        });
      } else if (ModalRoute.of(context)?.isCurrent != false) {
        context.showSnack(
          append
              ? '새 사진을 앨범 끝에 담았어요. 내 앨범에서 이어서 편집할 수 있어요.'
              : '내 앨범에서 이어서 편집할 수 있어요.',
        );
      }
    } catch (error) {
      if (_current(owner, identity))
        setState(
          () => _error = photosAdded
              ? '사진은 앨범에 추가됐어요. 이어서 편집하기를 눌러 다시 열어 주세요.'
              : error is MomentException
              ? error.message
              : append
              ? '사진을 추가하지 못했어요. 선택은 그대로 있으니 다시 시도해 주세요.'
              : '앨범을 열지 못했어요. 다시 시도해 주세요.',
        );
    } finally {
      if (_current(owner, identity)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(momentsCurrentUserIdProvider);
    ref.listen(momentsCurrentUserIdProvider, (previous, next) {
      if (previous != next) _lockSession();
    });
    final locked = _sessionChanged || actor == null || actor != _owner;
    final editing =
        !_busy && !_loadingAlbum && (_existing || _createdAlbum == null);
    return PopScope(
      canPop: !_busy,
      child: SocialWebFrame(
        section: WebSection.moments,
        child: Scaffold(
          backgroundColor: SocialStyle.background(context),
          appBar: ExperienceHeader(
            title: '월간 앨범',
            showNotifications: false,
            onBack: () {
              if (!_busy) Navigator.of(context).pop();
            },
          ),
          bottomNavigationBar: locked
              ? null
              : Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: _albumActions(context),
                ),
          body: locked
              ? const SocialEmpty(
                  title: '계정이 변경되었어요',
                  message: '나의 기록으로 돌아가 다시 시작해 주세요.',
                  icon: ExperienceIcon('Lock'),
                )
              : SafeArea(
                  top: false,
                  child: SocialContent(
                    maxWidth: 720,
                    child: ListView(
                      cacheExtent: 800,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                      children: [
                        Text(
                          _existing
                              ? '나의 한 달에,\n새 장면을 더해요.'
                              : momentMonth(widget.today ?? momentToday()) ==
                                    momentMonth(widget.month)
                              ? '지금까지의 순간을,\n한 권에 담아요.'
                              : '${widget.month.month}월의 순간들을,\n한 권에 담아요.',
                          style: ExperienceFormStyle.text(
                            context,
                            30,
                            weight: FontWeight.w600,
                          ).copyWith(height: 1.3, letterSpacing: -.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _existing
                              ? '고른 사진은 앨범의 마지막 장 뒤에 추가해요.\n직접 꾸민 표지와 기존 페이지는 그대로 간직해요.'
                              : '사진을 고르면 표지와 내지가 함께 완성돼요.\n만든 뒤에도 자유롭게 편집할 수 있어요.',
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            secondary: true,
                          ).copyWith(height: 1.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '사진 위에 꾸민 내용은 그대로 담고, 피드 본문은 가져오지 않아요.',
                          key: const ValueKey(
                            'monthly-moment-design-transfer-note',
                          ),
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            secondary: true,
                          ).copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 26),
                        if (_existing) ...[
                          Text(
                            _existingAlbum?.title ?? '저장한 앨범을 불러오는 중',
                            key: const ValueKey(
                              'monthly-moment-existing-title',
                            ),
                            style: ExperienceFormStyle.text(
                              context,
                              20,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '이미 만든 월간 앨범',
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                        ] else
                          TextField(
                            key: const ValueKey('monthly-moment-title'),
                            controller: _title,
                            enabled: editing,
                            maxLength: 60,
                            maxLines: 2,
                            minLines: 1,
                            decoration: ExperienceFormStyle.input(
                              context,
                              hint: '이 앨범의 제목',
                            ),
                            onChanged: (_) => setState(_rebuildPreview),
                          ),
                        const SizedBox(height: 18),
                        if (_loadingAlbum)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (_existing &&
                            !_loadingAlbum &&
                            _preview.isEmpty &&
                            _existingAlbum != null &&
                            (_existingAlbum!.coverPreviewUrl ??
                                    _existingAlbum!.coverImageUrl ??
                                    '')
                                .isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: _previewCanvas.aspectRatio,
                              child: SnapfitImage(
                                urlOrGs:
                                    _existingAlbum!.coverPreviewUrl ??
                                    _existingAlbum!.coverImageUrl!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        if (_preview.isNotEmpty) ...[
                          if (_existing) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  key: const ValueKey('monthly-preview-saved'),
                                  label: Text('기존 앨범 $_savedPageCount쪽'),
                                  selected: _page < _savedPageCount,
                                  onSelected: (_) => _showPreviewPage(0),
                                ),
                                ChoiceChip(
                                  key: const ValueKey(
                                    'monthly-preview-pending',
                                  ),
                                  label: Text('추가 예정 $_pendingPageCount쪽'),
                                  selected: _page >= _savedPageCount,
                                  onSelected: _pendingPageCount == 0
                                      ? null
                                      : (_) =>
                                            _showPreviewPage(_savedPageCount),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _pendingPageCount == 0
                                  ? '사진을 고르면 앨범 뒤에 더해질 페이지를 미리 볼 수 있어요.'
                                  : '추가 예정 페이지는 아직 저장되지 않았어요. 아래에서 사진을 바꿔 보세요.',
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ).copyWith(height: 1.6),
                            ),
                            const SizedBox(height: 14),
                          ],
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: _previewCanvas.aspectRatio,
                              child: PageView.builder(
                                key: const ValueKey('monthly-moment-preview'),
                                controller: _pages,
                                itemCount: _preview.length,
                                onPageChanged: (value) =>
                                    setState(() => _page = value),
                                itemBuilder: (context, index) => LayoutBuilder(
                                  builder: (context, constraints) {
                                    final preview = _preview[index];
                                    return ColoredBox(
                                      color: preview.color,
                                      child: TemplatePageRenderer(
                                        layers: preview.layers,
                                        width: constraints.maxWidth,
                                        height: constraints.maxHeight,
                                        designCanvasSize: _previewCanvas,
                                        preserveTypography: true,
                                        imageDecodeWidth: 1200,
                                        photoBuilder: (layer, decodeWidth) =>
                                            SnapfitImage(
                                              key: ValueKey(
                                                '${layer.id}:${layer.imageUrl}',
                                              ),
                                              urlOrGs: _displayPhotoSource(
                                                layer.imageUrl,
                                              ),
                                              fit: BoxFit.contain,
                                              memCacheWidth: decodeWidth,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: '이전 미리보기',
                                onPressed: _page == 0
                                    ? null
                                    : () => _pages.previousPage(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOut,
                                      ),
                                icon: const ExperienceIcon('ChevronLeft'),
                              ),
                              Flexible(
                                child: Text(
                                  _existing
                                      ? _page < _savedPageCount
                                            ? '기존 ${_page == 0 ? '표지' : '내지 $_page'}  ·  ${_page + 1} / $_savedPageCount'
                                            : '추가 예정  ·  ${_page - _savedPageCount + 1} / $_pendingPageCount'
                                      : '${_page == 0 ? '표지' : '내지 $_page'}  ·  ${_page + 1} / ${_preview.length}',
                                  key: const ValueKey(
                                    'monthly-preview-position',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: ExperienceFormStyle.text(
                                    context,
                                    12,
                                    secondary: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '다음 미리보기',
                                onPressed: _page == _preview.length - 1
                                    ? null
                                    : () => _pages.nextPage(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOut,
                                      ),
                                icon: const ExperienceIcon('ChevronRight'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _existing ? '새로 담을 사진' : '앨범에 담을 사진',
                                style: ExperienceFormStyle.text(
                                  context,
                                  18,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${_selected.length} / 9',
                              style: ExperienceFormStyle.text(
                                context,
                                14,
                                color: SocialStyle.accent(context),
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _existing
                              ? '아직 앨범에 담지 않은 사진이에요. 한 번에 아홉 장까지 고를 수 있어요.'
                              : '사진을 눌러 고르고, 마음에 드는 장면을 표지로 정해보세요.',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ).copyWith(height: 1.6),
                        ),
                        if (_loadingCandidates) ...[
                          const SizedBox(height: 8),
                          Text(
                            '돌아보기에서 고른 후보를 확인하고 있어요…',
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                        ] else if (_candidateError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _candidateError!,
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              key: const ValueKey('monthly-choices-retry'),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(
                                      _loadCandidateChoices(refresh: true),
                                    ),
                              child: const Text('후보 다시 불러오기'),
                            ),
                          ),
                        ] else if (_candidateChoices.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '돌아보기에서 고른 후보 ${_candidateChoices.length}장을 먼저 모았어요.',
                            key: const ValueKey('monthly-choices-summary'),
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (_photos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              _existing
                                  ? '새로 담을 사진이 없어요. 앨범에서 이어서 꾸며보세요.'
                                  : '이번 달에 저장한 사진이 아직 없어요.',
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 560
                                  ? 3
                                  : 2;
                              final width =
                                  (constraints.maxWidth - (columns - 1) * 12) /
                                  columns;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 16,
                                children: _orderedPhotos
                                    .map(
                                      (photo) => SizedBox(
                                        width: width,
                                        child: _choice(photo, editing),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        const SizedBox(height: 26),
                        const MomentPrivateNote(album: true),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _displayPhotoSource(String? source) {
    if (source == null) return '';
    for (final record in widget.records) {
      for (final photo in record.photos) {
        if (photo.storageUri == source && photo.url.isNotEmpty)
          return photo.url;
      }
    }
    return source;
  }

  // Keep completion beside the selection instead of below every unused photo.
  Widget _albumActions(BuildContext context) => DecoratedBox(
    key: const ValueKey('monthly-moment-actions'),
    decoration: BoxDecoration(
      color: SocialStyle.background(context),
      border: Border(top: BorderSide(color: SocialStyle.line(context))),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            // Reserve the shared 60px header and some body space with a keyboard.
            maxHeight:
                (MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom -
                        MediaQuery.paddingOf(context).vertical -
                        60)
                    .clamp(0.0, double.infinity) *
                .65,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (MediaQuery.viewInsetsOf(context).bottom == 0)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          '선택한 사진 ${_selected.length} / 9장',
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExperienceIcon(
                              'Lock',
                              size: 16,
                              color: SocialStyle.accent(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '나만 보기',
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  if (_createdAlbum != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '월간 앨범을 내 앨범에 저장했어요.',
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        color: SocialStyle.accent(context),
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_error != null || _previewError != null) ...[
                    const SizedBox(height: 8),
                    MomentErrorNotice(
                      message: _error ?? _previewError!,
                      onRetry: _existing && _existingAlbum == null
                          ? _loadExisting
                          : null,
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_existing) ...[
                    if (_photos.isNotEmpty)
                      FilledButton(
                        key: const ValueKey('monthly-moment-append'),
                        style: SocialStyle.primary(context),
                        onPressed:
                            _busy ||
                                _loadingCandidates ||
                                _loadingAlbum ||
                                _existingAlbum == null ||
                                _previewError != null ||
                                _selected.isEmpty
                            ? null
                            : () => _existingAction(append: true),
                        child: Text(
                          _busy
                              ? '앨범을 준비하고 있어요…'
                              : '새 사진 ${_selected.length}장 추가하기',
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey('monthly-moment-open-existing'),
                      onPressed:
                          _busy || _loadingAlbum || _existingAlbum == null
                          ? null
                          : () => _existingAction(append: false),
                      child: Text(
                        _photos.isEmpty ? '앨범 이어서 편집하기' : '추가 없이 이어서 편집',
                      ),
                    ),
                  ] else
                    FilledButton(
                      key: const ValueKey('monthly-moment-create'),
                      style: SocialStyle.primary(context),
                      onPressed:
                          _busy ||
                              _loadingCandidates ||
                              _selected.isEmpty ||
                              (_createdAlbum != null &&
                                  widget.onAlbumCreated == null)
                          ? null
                          : _create,
                      child: Text(
                        _busy
                            ? '앨범을 준비하고 있어요…'
                            : _createdAlbum != null
                            ? '앨범 이어서 편집하기'
                            : '이 사진으로 앨범 만들기',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _choice(MomentPhoto photo, bool editing) {
    final index = _selected.indexOf(photo.id);
    final selected = index >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          selected: selected,
          label:
              '${momentDateLabel(_dates[photo.id]!)} 사진${!_existing && index == 0 ? ', 표지' : ''}',
          child: Material(
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('moment-photo-select-${photo.id}'),
              onTap: editing ? () => _toggle(photo.id) : null,
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: MomentPhotoView(photo: photo, imageDecodeWidth: 384),
                  ),
                  if (selected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: SocialStyle.accent(context),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? SocialStyle.accent(context)
                            : Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: selected
                          ? Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (_candidateChoices.contains(photo.id))
          Text(
            '내가 고른 후보',
            key: ValueKey('monthly-photo-choice-${photo.id}'),
            textAlign: TextAlign.center,
            style: ExperienceFormStyle.text(
              context,
              11,
              color: SocialStyle.accent(context),
            ),
          ),
        if (selected && !_existing)
          TextButton(
            key: ValueKey('moment-photo-cover-${photo.id}'),
            onPressed: editing && index != 0 ? () => _cover(photo.id) : null,
            child: Text(index == 0 ? '표지 사진' : '표지로 선택'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              momentDateLabel(_dates[photo.id]!),
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ),
      ],
    );
  }
}
