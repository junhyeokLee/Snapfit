import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/navigation/web_unsaved_work_guard.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../data/moments_repository.dart';
import '../../data/moment_draft_store.dart';
import '../../domain/moment_draft.dart';
import '../../domain/moment_record.dart';
import '../providers/moments_providers.dart';
import '../widgets/moments_widgets.dart';

class MomentComposeScreen extends ConsumerStatefulWidget {
  const MomentComposeScreen({
    super.key,
    this.record,
    this.today,
    this.imagePicker,
    this.draftRecordId,
  });
  final MomentRecord? record;
  final DateTime? today;
  final ImagePicker? imagePicker;
  final String? draftRecordId;

  @override
  ConsumerState<MomentComposeScreen> createState() =>
      _MomentComposeScreenState();
}

class _MomentComposeScreenState extends ConsumerState<MomentComposeScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _caption;
  late final MomentDraftStore _draftStore;
  late String _recordId, _captionText;
  late DateTime _date;
  late List<MomentPhoto> _photos;
  MomentRecord? _originalRecord;
  final List<MomentUpload> _uploads = [];
  final Map<String, MomentDraftUpload> _draftUploadCache = {};
  bool _busy = false, _picking = false, _dirty = false, _allowPop = false;
  bool _sessionChanged = false, _loadingDraft = true, _savingDraft = false;
  bool _draftFinished = false, _discarding = false, _draftConflict = false;
  bool _restoredDraft = false, _disposed = false;
  int _operation = 0, _changes = 0, _persistedChanges = 0;
  String? _error, _owner, _draftVersion, _draftError, _loadError;
  Timer? _draftTimer;
  Future<bool>? _draftWrite;

  bool get _draftSaved => _dirty && _persistedChanges == _changes;
  bool get _editingLocked =>
      _busy ||
      _picking ||
      _loadingDraft ||
      _loadError != null ||
      _draftConflict ||
      _discarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _captionText = widget.record?.caption ?? '';
    _caption = TextEditingController(text: _captionText);
    _originalRecord = widget.record;
    _recordId = widget.record?.id ?? const Uuid().v4();
    _date = widget.record?.recordDate ?? widget.today ?? momentToday();
    _photos = List.of(widget.record?.photos ?? const <MomentPhoto>[]);
    _owner = ref.read(momentsCurrentUserIdProvider);
    _draftStore = ref.read(momentDraftStoreProvider);
    unawaited(_loadDraft());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_flushDraft());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _draftTimer?.cancel();
    // Route replacement and app backgrounding may bypass the back button. The
    // snapshot uses plain fields, so a pending write can finish after disposal.
    unawaited(_flushDraft());
    _operation++;
    _caption.dispose();
    super.dispose();
  }

  bool _sameOwner(String owner) =>
      mounted &&
      !_disposed &&
      !_sessionChanged &&
      owner == _owner &&
      owner == ref.read(momentsCurrentUserIdProvider);

  bool _current(String owner, int operation) =>
      _sameOwner(owner) && operation == _operation;

  void _accountChanged() {
    _operation++;
    _draftTimer?.cancel();
    _sessionChanged = true;
    _loadingDraft = false;
    _loadError = null;
    _busy = false;
    _picking = false;
    _dirty = false;
    _photos.clear();
    _uploads.clear();
    _draftUploadCache.clear();
    _captionText = '';
    _caption.clear();
    _error = null;
  }

  void _invalidateDrafts(String owner) {
    if (!_sameOwner(owner)) return;
    ref.invalidate(momentDraftsProvider);
    ref.invalidate(momentDraftsForOwnerProvider(owner));
    ref.invalidate(momentDraftSummariesForOwnerProvider(owner));
  }

  Future<void> _loadDraft() async {
    final owner = _owner;
    if (owner == null || !_sameOwner(owner)) return;
    final operation = _operation;
    if (!_loadingDraft || _loadError != null) {
      setState(() {
        _loadingDraft = true;
        _loadError = null;
      });
    }
    try {
      final id = widget.draftRecordId ?? widget.record?.id;
      final draft =
          await (id == null
                  ? _draftStore.latestNew(owner)
                  : _draftStore.load(owner, id))
              .timeout(const Duration(seconds: 12));
      if (!_current(owner, operation)) return;
      if (widget.draftRecordId != null && draft == null) {
        throw const MomentDraftException(
          '이 임시 작성은 이미 저장되거나 지워졌어요. 나의 기록으로 돌아가 주세요.',
        );
      }
      MomentRecord? freshOriginal;
      var checkedOriginal = false;
      var originalCheckFailed = false;
      if (draft?.originalRecord case final original?) {
        try {
          final journal = await ref
              .read(momentsRepositoryProvider)
              .listMonth(momentMonth(original.recordDate))
              .timeout(const Duration(seconds: 12));
          checkedOriginal = true;
          for (final record in journal.records) {
            if (record.id == original.id) {
              freshOriginal = record;
              break;
            }
          }
        } catch (_) {
          // Local recovery still works offline. The original revision is sent
          // to the server on save, so this cannot overwrite a newer record.
          originalCheckFailed = true;
        }
        if (!_current(owner, operation)) return;
      }
      if (!_current(owner, operation)) return;
      setState(() {
        _loadingDraft = false;
        _loadError = null;
        if (draft == null) return;
        _recordId = draft.recordId;
        _originalRecord = draft.originalRecord;
        _date = draft.recordDate;
        _captionText = draft.caption;
        _caption.text = draft.caption;
        final freshPhotos = {
          for (final photo
              in freshOriginal?.photos ??
                  widget.record?.photos ??
                  const <MomentPhoto>[])
            photo.id: photo,
        };
        _photos = [
          for (final photo in draft.existingPhotos)
            freshPhotos[photo.id]?.path == photo.path
                ? freshPhotos[photo.id]!
                : photo,
        ];
        _uploads.clear();
        _draftUploadCache.clear();
        for (final upload in draft.uploads) {
          _uploads.add(
            MomentUpload(
              id: upload.id,
              // Web image decoding expects a native JS typed array; the
              // immutable domain view cannot cross that engine boundary.
              bytes: kIsWeb ? Uint8List.fromList(upload.bytes) : upload.bytes,
              filename: upload.filename,
            ),
          );
          _draftUploadCache[upload.id] = upload;
        }
        _draftVersion = draft.version;
        _dirty = true;
        _changes = 1;
        _persistedChanges = 1;
        _restoredDraft = true;
        _draftConflict =
            checkedOriginal &&
            draft.originalRecord != null &&
            (freshOriginal == null ||
                freshOriginal!.revision != draft.originalRecord!.revision);
        if (_draftConflict) {
          _draftError =
              '다른 곳에서 이 기록이 바뀌었어요. 임시 작성은 그대로 보관했어요. 글을 복사하거나 나의 기록에서 최신 내용을 확인해 주세요.';
        } else if (originalCheckFailed) {
          _draftError = '임시 작성은 복원했어요. 최신 기록은 연결이 돌아온 뒤 저장할 때 다시 확인해요.';
        }
      });
    } catch (error) {
      if (!_current(owner, operation)) return;
      setState(() {
        _loadingDraft = false;
        _loadError = error is MomentDraftException
            ? error.message
            : '보관한 임시 작성을 확인하지 못했어요. 연결과 기기 저장 공간을 확인한 뒤 다시 불러와 주세요.';
      });
    }
  }

  MomentDraft _snapshot(String owner) => MomentDraft(
    ownerId: owner,
    recordId: _recordId,
    recordDate: _date,
    caption: _captionText,
    existingPhotos: List.of(_photos),
    uploads: [
      for (final upload in _uploads)
        _draftUploadCache.putIfAbsent(
          upload.id,
          () => MomentDraftUpload(
            id: upload.id,
            filename: upload.filename,
            bytes: upload.bytes,
          ),
        ),
    ],
    originalRecord: _originalRecord,
    updatedAt: DateTime.now().toUtc(),
    version: _draftVersion,
  );

  void _markChanged({bool immediate = false}) {
    _draftTimer?.cancel();
    setState(() {
      _dirty = true;
      _changes++;
      _draftError = null;
    });
    if (immediate) {
      unawaited(_flushDraft());
    } else {
      _draftTimer = Timer(const Duration(milliseconds: 350), () {
        unawaited(_flushDraft());
      });
    }
  }

  Future<bool> _flushDraft() async {
    _draftTimer?.cancel();
    final owner = _owner;
    if (!_dirty || _draftFinished) return true;
    if (owner == null ||
        _sessionChanged ||
        _loadingDraft ||
        _loadError != null ||
        _draftConflict ||
        _discarding ||
        (mounted && !_disposed && !_sameOwner(owner)))
      return false;
    final pending = _draftWrite;
    if (pending != null) {
      if (!await pending) return false;
      return _flushDraft();
    }
    if (_persistedChanges == _changes) return true;
    final generation = _changes;
    final snapshot = _snapshot(owner);
    final completion = Completer<bool>();
    _draftWrite = completion.future;
    if (_sameOwner(owner)) setState(() => _savingDraft = true);
    var success = false;
    try {
      if (!snapshot.hasContent && _originalRecord == null) {
        await _draftStore.remove(
          owner,
          _recordId,
          expectedVersion: _draftVersion,
        );
        _draftVersion = null;
        if (_changes == generation) {
          _dirty = false;
          _restoredDraft = false;
        }
      } else {
        final saved = await _draftStore.save(
          owner,
          snapshot,
          expectedVersion: _draftVersion,
        );
        _draftVersion = saved.version;
      }
      _persistedChanges = generation;
      success = true;
      if (_sameOwner(owner)) {
        setState(() => _draftError = null);
        _invalidateDrafts(owner);
      }
    } catch (error) {
      if (_sameOwner(owner))
        setState(() {
          _draftError = error is MomentDraftException
              ? error.message
              : '임시 저장하지 못했어요. 화면을 닫기 전에 다시 시도해 주세요.';
          if (error is MomentDraftConflictException) _draftConflict = true;
        });
    } finally {
      _draftWrite = null;
      if (_sameOwner(owner)) setState(() => _savingDraft = false);
      completion.complete(success);
    }
    if (success && _changes != generation) return _flushDraft();
    return success;
  }

  Future<void> _clearCompletedDraft(String owner) async {
    _draftTimer?.cancel();
    _draftFinished = true;
    // A different tab may have advanced this draft. Never delete its version.
    try {
      await _draftStore.remove(
        owner,
        _recordId,
        expectedVersion: _draftVersion,
      );
    } on MomentDraftException {
      // The saved server record remains authoritative; another local version
      // stays available instead of being removed by this completed editor.
    }
    _invalidateDrafts(owner);
  }

  Future<void> _discardDraft() async {
    if (_busy || _picking || _loadingDraft || _discarding) return;
    final owner = _owner;
    if (owner == null || !_sameOwner(owner)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('임시 작성을 지울까요?'),
        content: const Text(
          '아직 기록에 저장하지 않은 사진과 글을 이 기기에서 지워요. 이미 저장한 기록은 그대로 남아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('임시 작성 지우기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_sameOwner(owner)) return;
    _draftTimer?.cancel();
    setState(() => _discarding = true);
    final pending = _draftWrite;
    if (pending != null) await pending;
    if (!_sameOwner(owner)) return;
    try {
      await _draftStore.remove(
        owner,
        _recordId,
        expectedVersion: _draftVersion,
      );
      if (!_sameOwner(owner)) return;
      _invalidateDrafts(owner);
      setState(() {
        _dirty = false;
        _draftFinished = true;
        _allowPop = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sameOwner(owner)) Navigator.of(context).pop();
      });
    } catch (error) {
      if (_sameOwner(owner))
        setState(() {
          _discarding = false;
          _draftError = error is MomentDraftException
              ? error.message
              : '임시 작성을 지우지 못했어요. 다시 시도해 주세요.';
        });
    }
  }

  Future<void> _closeConflictedCopy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 화면의 변경을 닫을까요?'),
        content: const Text(
          '다른 창에서 보관한 임시 작성은 그대로 남아요. 이 화면에서만 바꾼 최근 내용은 사라져요. 필요한 글은 먼저 복사해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 보기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('이 화면 닫기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _sessionChanged) return;
    setState(() {
      _dirty = false;
      _draftFinished = true;
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _pick() async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    final remaining = 3 - _photos.length - _uploads.length;
    if (owner == null ||
        owner != _owner ||
        _editingLocked ||
        remaining < 1 ||
        _sessionChanged)
      return;
    final operation = ++_operation;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picker = widget.imagePicker ?? ImagePicker();
      final List<XFile> picked;
      if (remaining == 1) {
        final image = await picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        );
        picked = image == null ? [] : [image];
      } else {
        picked = await picker.pickMultiImage(
          limit: remaining,
          requestFullMetadata: false,
        );
      }
      if (!_current(owner, operation)) return;
      final additions = <MomentUpload>[];
      var skipped = false;
      for (final file in picked.take(remaining)) {
        if (await file.length() > 20 * 1024 * 1024) {
          skipped = true;
          continue;
        }
        final bytes = await file.readAsBytes();
        if (!_current(owner, operation)) return;
        if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
          skipped = true;
          continue;
        }
        additions.add(
          MomentUpload(
            id: const Uuid().v4(),
            bytes: bytes,
            filename: file.name,
          ),
        );
      }
      if (!_current(owner, operation)) return;
      setState(() {
        _uploads.addAll(additions);
        if (skipped) _error = '사진은 한 장당 20MB 이하로 선택해 주세요. 선택한 나머지 사진은 그대로 있어요.';
      });
      if (additions.isNotEmpty) _markChanged(immediate: true);
    } catch (_) {
      if (_current(owner, operation))
        setState(() => _error = '사진을 가져오지 못했어요. 사진 접근 권한을 확인한 뒤 다시 선택해 주세요.');
    } finally {
      if (_current(owner, operation)) setState(() => _picking = false);
    }
  }

  Future<void> _pickDate() async {
    if (_editingLocked || _sessionChanged) return;
    final operation = _operation;
    final today = widget.today ?? momentToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: '이 순간을 기록할 날짜',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (!mounted ||
        operation != _operation ||
        _sessionChanged ||
        picked == null)
      return;
    setState(() {
      _date = DateTime.utc(picked.year, picked.month, picked.day);
    });
    _markChanged(immediate: true);
  }

  Future<void> _back() async {
    if (_busy || _picking || _loadingDraft || _discarding) return;
    var canLeave = !_dirty || _draftSaved;
    if (!canLeave) {
      canLeave = await _flushDraft().timeout(
        const Duration(seconds: 12),
        onTimeout: () => false,
      );
    }
    if (!mounted) return;
    if (!canLeave) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('임시 저장을 확인하지 못했어요'),
          content: const Text(
            '지금 나가면 최근에 작성한 내용이 사라질 수 있어요. 이 화면에서 다시 저장해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 작성'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _save() async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (owner == null || owner != _owner || _editingLocked || _sessionChanged)
      return;
    if (_photos.isEmpty && _uploads.isEmpty) {
      setState(() => _error = '기억하고 싶은 사진을 한 장 이상 골라 주세요.');
      return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _flushDraft();
      if (!_current(owner, operation) || _draftConflict) return;
      final saved = await ref
          .read(momentsRepositoryProvider)
          .save(
            id: _recordId,
            recordDate: _date,
            caption: _caption.text.trim(),
            existingPhotos: List.of(_photos),
            uploads: List.of(_uploads),
            originalPhotos: _originalRecord?.photos ?? const [],
            expectedRevision: _originalRecord?.revision,
          );
      if (!_current(owner, operation)) return;
      await _clearCompletedDraft(owner);
      if (!_current(owner, operation)) return;
      ref.invalidate(momentsMonthProvider);
      setState(() {
        _dirty = false;
        _allowPop = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _current(owner, operation))
          Navigator.of(context).pop(saved);
      });
    } catch (error) {
      if (_current(owner, operation))
        setState(
          () => _error = error is MomentException
              ? error.message
              : '기록을 저장하지 못했어요. 사진과 글은 그대로 있으니 다시 저장해 주세요.',
        );
    } finally {
      if (_current(owner, operation)) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (_originalRecord == null ||
        owner == null ||
        _editingLocked ||
        _sessionChanged)
      return;
    final operation = _operation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 기록을 삭제할까요?'),
        content: const Text('기록에 저장한 사진과 글을 삭제해요. 이미 만든 앨범은 그대로 남아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_current(owner, operation)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _flushDraft();
      if (!_current(owner, operation) || _draftConflict) return;
      await ref.read(momentsRepositoryProvider).delete(_originalRecord!);
      if (!_current(owner, operation)) return;
      await _clearCompletedDraft(owner);
      if (!_current(owner, operation)) return;
      ref.invalidate(momentsMonthProvider);
      setState(() {
        _dirty = false;
        _allowPop = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_current(owner, operation)) Navigator.of(context).pop(true);
      });
    } catch (error) {
      if (_current(owner, operation))
        setState(
          () => _error = error is MomentException
              ? error.message
              : '기록을 삭제하지 못했어요. 다시 시도해 주세요.',
        );
    } finally {
      if (_current(owner, operation)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(momentsCurrentUserIdProvider);
    ref.listen(momentsCurrentUserIdProvider, (previous, next) {
      if (previous != next) _accountChanged();
    });
    final locked = _sessionChanged || actor == null || actor != _owner;
    final count = _photos.length + _uploads.length;
    return WebUnsavedWorkGuard(
      hasUnsavedChanges: () =>
          !_draftFinished && !_sessionChanged && _dirty && !_draftSaved,
      child: PopScope(
        canPop:
            _allowPop ||
            ((!_dirty || _draftSaved) &&
                !_busy &&
                !_picking &&
                !_loadingDraft &&
                !_discarding),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: SocialWebFrame(
          section: WebSection.moments,
          child: Scaffold(
            backgroundColor: SocialStyle.background(context),
            appBar: ExperienceHeader(
              title: _originalRecord == null ? '오늘의 순간' : '기록 다듬기',
              showNotifications: false,
              onBack: _back,
              actions: [
                if (_originalRecord != null && !locked)
                  IconButton(
                    tooltip: '기록 삭제',
                    onPressed: _editingLocked ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            body: locked
                ? const SocialEmpty(
                    title: '계정이 변경되었어요',
                    message: '나의 기록으로 돌아가 다시 시작해 주세요.',
                    icon: Icons.lock_outline_rounded,
                  )
                : _loadingDraft
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('보관한 기록을 확인하고 있어요'),
                      ],
                    ),
                  )
                : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MomentErrorNotice(message: _loadError!),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            key: const ValueKey('moment-draft-load-retry'),
                            onPressed: _loadDraft,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('임시 작성 다시 불러오기'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SafeArea(
                    top: false,
                    child: SocialContent(
                      maxWidth: 680,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                        children: [
                          Text(
                            '남기고 싶은 순간이\n있었나요?',
                            style: ExperienceFormStyle.text(
                              context,
                              30,
                              weight: FontWeight.w600,
                            ).copyWith(height: 1.3, letterSpacing: -.8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '사진은 한 번에 세 장까지. 한 장만 남겨도 좋아요.',
                            style: ExperienceFormStyle.text(
                              context,
                              13,
                              secondary: true,
                            ).copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 18),
                          _draftStatus(context),
                          const SizedBox(height: 22),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              key: const ValueKey('moment-date'),
                              onPressed: _editingLocked ? null : _pickDate,
                              icon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                              ),
                              label: Text(
                                '${_date.year}년 ${momentDateLabel(_date)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          for (var i = 0; i < _photos.length; i++)
                            _photoTile(
                              key: ValueKey(_photos[i].id),
                              child: MomentPhotoView(
                                key: ValueKey('moment-existing-photo-$i'),
                                photo: _photos[i],
                                aspectRatio:
                                    _photos[i].width > 0 &&
                                        _photos[i].height > 0
                                    ? (_photos[i].width / _photos[i].height)
                                          .clamp(.7, 1.8)
                                    : 1,
                              ),
                              onRemove: () {
                                setState(() => _photos.removeAt(i));
                                _markChanged(immediate: true);
                              },
                            ),
                          for (var i = 0; i < _uploads.length; i++)
                            _photoTile(
                              key: ValueKey(_uploads[i].id),
                              child: MomentPhotoView(
                                key: ValueKey('moment-new-photo-$i'),
                                bytes: _uploads[i].bytes,
                                useIntrinsicSize: true,
                              ),
                              onRemove: () {
                                setState(() {
                                  final removed = _uploads.removeAt(i);
                                  _draftUploadCache.remove(removed.id);
                                });
                                _markChanged(immediate: true);
                              },
                            ),
                          if (count < 3)
                            Material(
                              color: SocialStyle.paper(context),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                key: const ValueKey('moment-pick-photos'),
                                onTap: _editingLocked ? null : _pick,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 38,
                                    horizontal: 18,
                                  ),
                                  child: Column(
                                    children: [
                                      if (_picking)
                                        const SizedBox.square(
                                          dimension: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 32,
                                          color: SocialStyle.accent(context),
                                        ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _picking
                                            ? '사진을 가져오고 있어요'
                                            : '사진 고르기  $count / 3',
                                        style: ExperienceFormStyle.text(
                                          context,
                                          14,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 28),
                          Text(
                            '그 순간의 한 줄',
                            style: ExperienceFormStyle.text(
                              context,
                              16,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const ValueKey('moment-caption'),
                            controller: _caption,
                            enabled: !_busy && !_discarding,
                            readOnly: _draftConflict,
                            maxLength: 200,
                            minLines: 3,
                            maxLines: 6,
                            onChanged: (value) {
                              _captionText = value;
                              _markChanged();
                            },
                            decoration: ExperienceFormStyle.input(
                              context,
                              hint:
                                  '오늘의 기분, 함께한 사람, 기억하고 싶은 이야기.\n글은 비워 두어도 괜찮아요.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const MomentPrivateNote(),
                          if (_error != null) ...[
                            const SizedBox(height: 20),
                            MomentErrorNotice(message: _error!),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            key: const ValueKey('moment-save'),
                            onPressed: _editingLocked ? null : _save,
                            style: SocialStyle.primary(context),
                            child: Text(_busy ? '기록을 저장하고 있어요…' : '나의 기록에 저장'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _draftStatus(BuildContext context) {
    final message =
        _draftError ??
        (_savingDraft
            ? '이 기기에 임시 저장 중…'
            : _draftSaved
            ? (_restoredDraft ? '보관한 기록을 이어서 작성하고 있어요' : '이 기기에 임시 저장했어요')
            : _dirty
            ? '잠시 후 이 기기에 임시 저장해요'
            : '사진과 글은 이 기기에 임시 저장돼요');
    return Container(
      key: const ValueKey('moment-draft-status'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SocialStyle.paper(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _draftError != null
                    ? Icons.info_outline_rounded
                    : _draftSaved
                    ? Icons.check_circle_outline_rounded
                    : Icons.save_outlined,
                size: 18,
                color: SocialStyle.accent(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: ExperienceFormStyle.text(
                    context,
                    12,
                  ).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '같은 계정과 기기에서 이어 쓸 수 있어요. 임시 작성은 이 기기에만 보관해요.',
            style: ExperienceFormStyle.text(
              context,
              11,
              secondary: true,
            ).copyWith(height: 1.5),
          ),
          if (_dirty || _draftVersion != null)
            Wrap(
              spacing: 8,
              children: [
                if (_draftError != null && !_draftConflict)
                  TextButton(
                    key: const ValueKey('moment-draft-retry'),
                    onPressed: _busy || _discarding
                        ? null
                        : () => unawaited(_flushDraft()),
                    child: const Text('임시 저장 다시 시도'),
                  ),
                TextButton(
                  key: const ValueKey('moment-draft-discard'),
                  onPressed: _busy || _picking || _discarding
                      ? null
                      : _draftConflict && !_draftSaved
                      ? _closeConflictedCopy
                      : _discardDraft,
                  child: Text(
                    _draftConflict && !_draftSaved
                        ? '이 화면의 변경 닫기'
                        : '임시 작성 지우기',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _photoTile({
    required Key key,
    required Widget child,
    required VoidCallback onRemove,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(bottom: 12),
    child: Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filledTonal(
            tooltip: '이 사진 빼기',
            onPressed: _editingLocked ? null : onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    ),
  );
}
