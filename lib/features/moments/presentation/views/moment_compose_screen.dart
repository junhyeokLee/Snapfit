import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/navigation/web_unsaved_work_guard.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../../social/presentation/social_actions.dart';
import '../../../billing/data/billing_provider.dart';
import '../../data/moments_repository.dart';
import '../../data/moment_draft_store.dart';
import '../../data/moment_photo_codec.dart';
import '../../domain/moment_draft.dart';
import '../../domain/moment_record.dart';
import '../../domain/moment_photo_design.dart';
import '../../domain/moment_photo_format.dart';
import '../providers/moments_providers.dart';
import '../providers/moment_entry_refresh_provider.dart';
import '../providers/moment_publication_providers.dart';
import '../widgets/moments_widgets.dart';
import '../widgets/moment_publication_panel.dart';
import '../widgets/moment_photo_format_picker.dart';
import '../widgets/moment_compose_notebook.dart';
import 'moment_photo_editor_screen.dart';

typedef MomentPhotoEditorCallback =
    Future<MomentPhotoDesign?> Function(
      BuildContext context, {
      MomentPhoto? photo,
      MomentUpload? upload,
    });

typedef _RemovedMomentPhoto = ({
  String recordId,
  DateTime date,
  int index,
  MomentPhoto? photo,
  MomentUpload? upload,
  MomentDraftUpload? draftUpload,
});

class MomentComposeScreen extends ConsumerStatefulWidget {
  const MomentComposeScreen({
    super.key,
    this.record,
    this.today,
    this.imagePicker,
    this.draftRecordId,
    this.photoEditor,
  });
  final MomentRecord? record;
  final DateTime? today;
  final ImagePicker? imagePicker;
  final String? draftRecordId;
  final MomentPhotoEditorCallback? photoEditor;

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
  DateTime? _serverToday;
  late List<MomentPhoto> _photos;
  MomentRecord? _originalRecord;
  MomentRecord? _savedRecord;
  bool _sharePublicly = false;
  String? _publicPhotoId;
  String _publicationRequestId = const Uuid().v4();
  final List<MomentUpload> _uploads = [];
  final Map<String, MomentDraftUpload> _draftUploadCache = {};
  CoverSize _newPhotoCover = defaultCoverSize;
  bool _busy = false, _picking = false, _dirty = false, _allowPop = false;
  bool _decorating = false, _changingPhotos = false;
  _RemovedMomentPhoto? _removedPhoto;
  bool _sessionChanged = false, _loadingDraft = true, _savingDraft = false;
  bool _draftFinished = false, _discarding = false, _draftConflict = false;
  bool _restoredDraft = false, _disposed = false;
  String? _pendingSaveFingerprint;
  int _operation = 0, _changes = 0, _persistedChanges = 0;
  String? _error, _owner, _draftVersion, _draftError, _loadError;
  String _busyMessage = '기록을 저장하고 있어요';
  Timer? _draftTimer;
  Future<bool>? _draftWrite;

  bool get _draftSaved => _dirty && _persistedChanges == _changes;
  bool get _photoDateLocked =>
      _serverToday != null && momentDate(_date) != _serverToday;
  bool get _originalPhotosUnchanged =>
      _originalRecord != null &&
      _uploads.isEmpty &&
      listEquals(
        _photos.map((photo) => jsonEncode(photo.toJson())).toList(),
        _originalRecord!.photos
            .map((photo) => jsonEncode(photo.toJson()))
            .toList(),
      );
  // Design-only edits on a past record: same photo IDs, no new uploads.
  bool get _originalPhotoIdsUnchanged =>
      _originalRecord != null &&
      _uploads.isEmpty &&
      listEquals(
        _photos.map((p) => p.id).toList(),
        _originalRecord!.photos.map((p) => p.id).toList(),
      );
  bool get _canSaveRecord =>
      !_photoDateLocked ||
      (_originalRecord != null &&
          _date == _originalRecord!.recordDate &&
          _originalPhotoIdsUnchanged) ||
      // A timed-out save may already exist on the server. Only its RPC can
      // reconcile the same request after midnight without duplicating a day.
      _pendingSaveFingerprint != null;
  bool get _editingLocked =>
      _busy ||
      _picking ||
      _decorating ||
      _changingPhotos ||
      _loadingDraft ||
      _loadError != null ||
      _draftConflict ||
      _discarding ||
      _savedRecord != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _captionText = widget.record?.caption ?? '';
    _caption = TextEditingController(text: _captionText);
    _originalRecord = widget.record;
    _recordId = widget.record?.id ?? const Uuid().v4();
    _date = widget.record?.recordDate ?? widget.today ?? momentToday();
    _serverToday = widget.today;
    _photos = List.of(widget.record?.photos ?? const <MomentPhoto>[]);
    _owner = ref.read(momentsCurrentUserIdProvider);
    _draftStore = ref.read(momentDraftStoreProvider);
    unawaited(_loadDraft());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_flushDraft());
    } else {
      unawaited(_refreshServerDay());
    }
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

  Future<bool> _refreshServerDay() async {
    final owner = _owner;
    if (owner == null || !_sameOwner(owner)) return false;
    try {
      final journal = await ref
          .read(momentsRepositoryProvider)
          .listMonth(null)
          .timeout(const Duration(seconds: 12));
      if (!_sameOwner(owner)) return false;
      // 늦게 도착한 이전 날짜 응답이 자정 뒤의 사진 잠금을 풀지 않게 한다.
      if (_serverToday != null && journal.today.isBefore(_serverToday!)) {
        return false;
      }
      setState(() {
        _serverToday = journal.today;
        if (_removedPhoto != null && _removedPhoto!.date != journal.today) {
          _removedPhoto = null;
        }
        if (_originalRecord == null &&
            !_restoredDraft &&
            _uploads.isEmpty &&
            _pendingSaveFingerprint == null) {
          _date = journal.today;
        }
      });
      return true;
    } catch (_) {
      if (_sameOwner(owner)) {
        setState(() => _error = '오늘 날짜를 확인하지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요.');
      }
      return false;
    }
  }

  Future<bool> _ensurePhotoDate() async {
    if (!await _refreshServerDay()) return false;
    if (!_photoDateLocked) return true;
    if (mounted) {
      setState(
        () => _error = '사진은 한국 시간 기준 당일에만 추가하거나 바꿀 수 있어요. 지난 기록은 글만 수정할 수 있어요.',
      );
    }
    return false;
  }

  void _accountChanged() {
    _operation++;
    _draftTimer?.cancel();
    _sessionChanged = true;
    _loadingDraft = false;
    _loadError = null;
    _busy = false;
    _picking = false;
    _decorating = false;
    _changingPhotos = false;
    _removedPhoto = null;
    _dirty = false;
    _photos.clear();
    _uploads.clear();
    _draftUploadCache.clear();
    _captionText = '';
    _caption.clear();
    _error = null;
    _savedRecord = null;
    _pendingSaveFingerprint = null;
    _serverToday = null;
    _sharePublicly = false;
    _publicPhotoId = null;
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
      DateTime? freshToday;
      if (draft?.originalRecord case final original?) {
        try {
          final journal = await ref
              .read(momentsRepositoryProvider)
              .listMonth(momentMonth(original.recordDate))
              .timeout(const Duration(seconds: 12));
          checkedOriginal = true;
          freshToday = journal.today;
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
      if (!_current(owner, operation)) return;
      setState(() {
        _loadingDraft = false;
        _loadError = null;
        if (freshToday != null) _serverToday = freshToday;
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
                ? photo.withUrl(freshPhotos[photo.id]!.url)
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
              design: upload.design,
            ),
          );
          _draftUploadCache[upload.id] = upload;
        }
        _draftVersion = draft.version;
        _dirty = true;
        _changes = 1;
        _persistedChanges = 1;
        _restoredDraft = true;
        _pendingSaveFingerprint = draft.hasPendingSave
            ? draft.pendingSaveFingerprint
            : null;
        _draftConflict =
            _pendingSaveFingerprint == null &&
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
            design: upload.design,
          ),
        ),
    ],
    originalRecord: _originalRecord,
    updatedAt: DateTime.now().toUtc(),
    version: _draftVersion,
    pendingSaveFingerprint: _pendingSaveFingerprint,
  );

  void _markChanged({bool immediate = false}) {
    _draftTimer?.cancel();
    setState(() {
      _pendingSaveFingerprint = null;
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
    _removedPhoto = null;
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
    if (_busy || _picking || _changingPhotos || _loadingDraft || _discarding)
      return;
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
        _removedPhoto = null;
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
      if (!await _ensurePhotoDate() || !_current(owner, operation)) return;
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
        PreparedMomentPhoto prepared;
        try {
          prepared = await prepareMomentPhoto(bytes, maxEdge: 1600);
        } on MomentException {
          skipped = true;
          continue;
        }
        if (!_current(owner, operation)) return;
        additions.add(
          MomentUpload(
            id: const Uuid().v4(),
            bytes: bytes,
            filename: file.name,
            design: newMomentPhotoDesign(
              photoSize: Size(
                prepared.width.toDouble(),
                prepared.height.toDouble(),
              ),
              cover: _newPhotoCover,
            ),
          ),
        );
      }
      if (!_current(owner, operation)) return;
      if (!await _ensurePhotoDate() || !_current(owner, operation)) return;
      setState(() {
        _uploads.addAll(additions);
        if (skipped)
          _error = '읽을 수 있는 20MB 이하의 사진만 추가했어요. 선택한 나머지 사진은 그대로 있어요.';
      });
      if (additions.isNotEmpty) _markChanged(immediate: true);
    } catch (_) {
      if (_current(owner, operation))
        setState(() => _error = '사진을 가져오지 못했어요. 사진 접근 권한을 확인한 뒤 다시 선택해 주세요.');
    } finally {
      if (_current(owner, operation)) setState(() => _picking = false);
    }
  }

  Future<void> _selectNewPhotoFormat() async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (owner == null || !_sameOwner(owner) || _editingLocked) return;
    final operation = ++_operation;
    setState(() => _decorating = true);
    try {
      if (!await _ensurePhotoDate() || !_current(owner, operation)) return;
      final cover = await showMomentPhotoFormatPicker(
        context,
        selectedCover: _newPhotoCover,
        title: '새 사진의 앨범 규격',
        description: '이후 추가하는 사진에만 적용돼요. 이미 남긴 사진은 꾸미기에서 한 장씩 바꿀 수 있어요.',
      );
      if (_current(owner, operation) && cover != null) {
        HapticFeedback.selectionClick();
        setState(() => _newPhotoCover = cover);
      }
    } finally {
      if (_current(owner, operation)) setState(() => _decorating = false);
    }
  }

  Future<void> _decoratePhoto(String photoId) async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (owner == null || !_sameOwner(owner) || _editingLocked) return;
    final photo = _photos.where((item) => item.id == photoId).firstOrNull;
    final upload = _uploads.where((item) => item.id == photoId).firstOrNull;
    if (photo == null && upload == null) return;
    final operation = ++_operation;
    setState(() {
      _decorating = true;
      _error = null;
    });
    try {
      if (!await _ensurePhotoDate() || !_current(owner, operation)) return;
      final design = await (widget.photoEditor ?? openMomentPhotoEditor)(
        context,
        photo: photo,
        upload: upload,
      );
      if (!_current(owner, operation) || design == null) return;
      if (!await _ensurePhotoDate() || !_current(owner, operation)) return;
      final existingIndex = _photos.indexWhere((item) => item.id == photoId);
      final uploadIndex = _uploads.indexWhere((item) => item.id == photoId);
      if (existingIndex < 0 && uploadIndex < 0) return;
      setState(() {
        if (existingIndex >= 0) {
          _photos[existingIndex] = _photos[existingIndex].withDesign(design);
        } else {
          final original = _uploads[uploadIndex];
          _uploads[uploadIndex] = original.withDesign(design);
          _draftUploadCache.remove(photoId);
        }
        _publicationRequestId = const Uuid().v4();
      });
      _markChanged(immediate: true);
    } catch (_) {
      if (_current(owner, operation)) {
        setState(
          () => _error = '사진 꾸미기를 열지 못했어요. 원본과 작성한 글은 그대로 있어요. 다시 시도해 주세요.',
        );
      }
    } finally {
      if (_current(owner, operation)) setState(() => _decorating = false);
    }
  }

  Future<void> _removePhoto(String photoId) async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (owner == null || !_sameOwner(owner) || _photoControlsLocked) return;
    if (!_availablePhotoIds.contains(photoId)) return;
    final operation = ++_operation;
    final recordId = _recordId;
    final date = momentDate(_date);
    setState(() {
      _changingPhotos = true;
      _error = null;
    });
    try {
      if (!await _ensurePhotoDate() ||
          !_current(owner, operation) ||
          recordId != _recordId ||
          date != momentDate(_date))
        return;
      // 날짜 응답을 기다리는 동안 달라진 목록 위치로 다른 사진을 빼지 않게 한다.
      final photoIndex = _photos.indexWhere((photo) => photo.id == photoId);
      final uploadIndex = _uploads.indexWhere((photo) => photo.id == photoId);
      if (photoIndex < 0 && uploadIndex < 0) return;
      setState(() {
        _removedPhoto = (
          recordId: recordId,
          date: date,
          index: photoIndex >= 0 ? photoIndex : uploadIndex,
          photo: photoIndex >= 0 ? _photos.removeAt(photoIndex) : null,
          upload: uploadIndex >= 0 ? _uploads.removeAt(uploadIndex) : null,
          draftUpload: _draftUploadCache.remove(photoId),
        );
      });
      _markChanged(immediate: true);
    } finally {
      if (_current(owner, operation)) {
        setState(() => _changingPhotos = false);
      }
    }
  }

  Future<void> _undoPhotoRemoval() async {
    final removed = _removedPhoto;
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (removed == null ||
        owner == null ||
        !_sameOwner(owner) ||
        _photoControlsLocked)
      return;
    if (_photos.length + _uploads.length >= 3) {
      setState(() => _error = '사진이 3장이라 되돌릴 수 없어요.');
      return;
    }
    final operation = ++_operation;
    setState(() {
      _changingPhotos = true;
      _error = null;
    });
    try {
      if (!await _ensurePhotoDate() ||
          !_current(owner, operation) ||
          _removedPhoto != removed ||
          removed.recordId != _recordId ||
          removed.date != momentDate(_date))
        return;
      final photoId = removed.photo?.id ?? removed.upload!.id;
      if (_availablePhotoIds.contains(photoId)) return;
      setState(() {
        if (removed.photo case final photo?) {
          _photos.insert(removed.index.clamp(0, _photos.length), photo);
        } else if (removed.upload case final upload?) {
          _uploads.insert(removed.index.clamp(0, _uploads.length), upload);
          if (removed.draftUpload case final cached?) {
            _draftUploadCache[upload.id] = cached;
          }
        }
        // 날짜·계정 확인이 실패하면 다시 시도할 수 있도록 복구 항목을 유지한다.
        _removedPhoto = null;
      });
      _markChanged(immediate: true);
    } finally {
      if (_current(owner, operation)) {
        setState(() => _changingPhotos = false);
      }
    }
  }

  Future<void> _back() async {
    if (_busy ||
        _picking ||
        _decorating ||
        _changingPhotos ||
        _loadingDraft ||
        _discarding)
      return;
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
    if (owner == null ||
        owner != _owner ||
        _busy ||
        _sessionChanged ||
        (_savedRecord == null && _editingLocked))
      return;
    if (_sharePublicly && !_availablePhotoIds.contains(_publicPhotoId)) {
      setState(() => _error = '피드에 보여줄 사진 한 장을 골라 주세요.');
      return;
    }
    if (_photos.isEmpty && _uploads.isEmpty) {
      setState(() => _error = '기억하고 싶은 사진을 한 장 이상 골라 주세요.');
      return;
    }
    final operation = ++_operation;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _busyMessage = '기록을 저장하고 있어요';
      _error = null;
    });
    try {
      if (_savedRecord == null) {
        if (!await _refreshServerDay() || !_current(owner, operation)) return;
        if (!_canSaveRecord) {
          setState(
            () => _error =
                '날짜가 지나 사진을 저장할 수 없어요. 임시 작성은 보관되어 있어요. 지난 기록은 원래 사진을 유지한 채 글만 수정할 수 있어요.',
          );
          return;
        }
      }
      MomentRecord? saved = _savedRecord;
      if (saved == null) {
        // Persist the exact attempted payload before its response can be lost.
        _pendingSaveFingerprint = _snapshot(owner).saveFingerprint;
        _dirty = true;
        _changes++;
        if (!await _flushDraft()) {
          if (_current(owner, operation)) {
            setState(
              () => _error = '저장 재시도를 위해 임시 작성을 먼저 보관해야 해요. 임시 저장을 다시 시도해 주세요.',
            );
          }
          return;
        }
        if (!_current(owner, operation) || _draftConflict) return;
        saved = await ref
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
      }
      if (!_current(owner, operation)) return;
      _savedRecord = saved;
      await _clearCompletedDraft(owner);
      if (!_current(owner, operation)) return;
      ref.invalidate(momentsMonthProvider);
      ref.invalidate(momentEntryJournalProvider);
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(myPointLedgerProvider);
      ref.invalidate(pointLedgerHistoryProvider);
      setState(() {
        _dirty = false;
      });
      if (_sharePublicly) {
        await ref
            .read(momentPublicationRepositoryProvider)
            .publish(
              record: saved,
              photoId: _publicPhotoId!,
              requestId: _publicationRequestId,
              context: context,
              canContinue: () => _current(owner, operation),
            );
        if (!_current(owner, operation)) return;
        invalidateSocial(ref);
        ref.invalidate(momentPublicationStateProvider(saved.id));
      } else {
        // A no-op save can retain its server revision. Explicitly withdraw an
        // older public copy before confirming the selected private state.
        await ref
            .read(momentPublicationRepositoryProvider)
            .makePrivate(saved.id);
        if (!_current(owner, operation)) return;
        invalidateSocial(ref);
        ref.invalidate(momentPublicationStateProvider(saved.id));
      }
      if (!_current(owner, operation)) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _current(owner, operation))
          Navigator.of(context).pop(saved);
      });
    } catch (error) {
      if (_current(owner, operation))
        setState(
          () => _error = _savedRecord != null
              ? _sharePublicly
                    ? '기록은 저장됐어요. 피드 공개를 다시 시도하거나 나만 보기로 마쳐 주세요.'
                    : '기록은 저장됐어요. 나만 보기 설정을 다시 확인해 주세요.'
              : error is MomentException
              ? error.message
              : '기록을 저장하지 못했어요. 사진과 글은 그대로 있으니 다시 저장해 주세요.',
        );
    } finally {
      if (_current(owner, operation)) setState(() => _busy = false);
    }
  }

  List<String> get _availablePhotoIds => [
    ..._photos.map((photo) => photo.id),
    ..._uploads.map((photo) => photo.id),
  ];

  Future<void> _finishPrivately() async {
    final saved = _savedRecord;
    final owner = _owner;
    if (saved == null || owner == null || !_sameOwner(owner) || _busy) return;
    final operation = ++_operation;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _busyMessage = '나만 보기로 마무리하고 있어요';
    });
    try {
      await ref.read(momentPublicationRepositoryProvider).makePrivate(saved.id);
      if (!_current(owner, operation)) return;
      invalidateSocial(ref);
      ref.invalidate(momentPublicationStateProvider(saved.id));
      setState(() {
        _sharePublicly = false;
        _allowPop = true;
      });
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (_current(owner, operation)) {
        setState(() => _error = '공개 상태를 확인하지 못했어요. 연결을 확인한 뒤 다시 눌러 주세요.');
      }
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _busyMessage = '기록을 삭제하고 있어요';
      _error = null;
    });
    try {
      await _flushDraft();
      if (!_current(owner, operation) || _draftConflict) return;
      await ref.read(momentsRepositoryProvider).delete(_originalRecord!);
      if (!_current(owner, operation)) return;
      invalidateSocial(ref);
      ref.invalidate(momentPublicationStateProvider(_originalRecord!.id));
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
    ref.listen(momentEntryRefreshProvider, (previous, next) {
      if (previous != next) unawaited(_refreshServerDay());
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
                !_changingPhotos &&
                !_loadingDraft &&
                !_discarding),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 저장 중 웹 내비게이션·헤더·본문과 키보드 접근을 함께 잠근다.
            ExcludeSemantics(
              excluding: _busy,
              child: ExcludeFocus(
                excluding: _busy,
                child: AbsorbPointer(
                  absorbing: _busy,
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
                              icon: const ExperienceIcon('Trash2', size: 24),
                            ),
                        ],
                      ),
                      body: locked
                          ? const SocialEmpty(
                              title: '계정이 변경되었어요',
                              message: '나의 기록으로 돌아가 다시 시작해 주세요.',
                              icon: ExperienceIcon('Lock', size: 28),
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
                                      key: const ValueKey(
                                        'moment-draft-load-retry',
                                      ),
                                      onPressed: _loadDraft,
                                      icon: const ExperienceIcon('RefreshCw'),
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
                                child: _composeContent(context, count),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if (_busy) _busyOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _busyOverlay(BuildContext context) => Positioned.fill(
    key: const ValueKey('moment-save-overlay'),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          key: const ValueKey('moment-save-barrier'),
          dismissible: false,
          color: ExperienceFormStyle.ink(context).withValues(alpha: .18),
        ),
        Center(
          child: Semantics(
            liveRegion: true,
            label: _busyMessage,
            excludeSemantics: true,
            child: Material(
              color: ExperienceFormStyle.surface(context),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 26,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _busyMessage,
                      key: const ValueKey('moment-save-status'),
                      style: ExperienceFormStyle.text(context, 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _composeContent(BuildContext context, int count) => ListView(
    key: const ValueKey('moment-compose-scroll'),
    cacheExtent: 800,
    physics: _busy ? const NeverScrollableScrollPhysics() : null,
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
    children: [
      MomentComposeNotebook(
        date: _date,
        dateConfirmed: _serverToday != null,
        photoContent: _notebookPhotos(context, count),
        captionController: _caption,
        captionEnabled:
            !_busy && !_discarding && !_decorating && _savedRecord == null,
        captionReadOnly: _draftConflict,
        onCaptionChanged: (value) {
          _captionText = value;
          _markChanged();
        },
      ),
      const SizedBox(height: 10),
      _datePolicy(context),
      if (_photoDateLocked &&
          _originalRecord != null &&
          !_originalPhotosUnchanged)
        TextButton(
          key: const ValueKey('moment-restore-original-photos'),
          onPressed: _editingLocked
              ? null
              : () {
                  setState(() {
                    _photos = List.of(_originalRecord!.photos);
                    _uploads.clear();
                    _draftUploadCache.clear();
                    _removedPhoto = null;
                  });
                  _markChanged(immediate: true);
                },
          child: const Text('저장된 사진으로 되돌리고 글만 수정하기'),
        ),
      const SizedBox(height: 14),
      if (_originalRecord != null && _savedRecord == null) ...[
        _existingPublicationStatus(),
        const SizedBox(height: 12),
      ],
      _shareOptions(context),
      const SizedBox(height: 22),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExperienceIcon(
            'BookOpen',
            size: 28,
            color: SocialStyle.accent(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사진을 모아, 한 달의 앨범으로',
                  style: ExperienceFormStyle.text(
                    context,
                    16,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '앨범에 담을 사진은 나중에 골라요.',
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _draftStatus(context),
      if (_error != null) ...[
        const SizedBox(height: 16),
        MomentErrorNotice(message: _error!),
      ],
      const SizedBox(height: 20),
      FilledButton(
        key: const ValueKey('moment-save'),
        onPressed:
            _busy ||
                (_savedRecord == null &&
                    (_editingLocked || !_canSaveRecord || count == 0))
            ? null
            : _save,
        style: SocialStyle.primary(context),
        child: Text(
          _busy
              ? (_savedRecord != null && _sharePublicly
                    ? '피드에 공개하고 있어요…'
                    : '기록을 저장하고 있어요…')
              : _savedRecord != null
              ? (_sharePublicly ? '피드 공개 다시 시도' : '나만 보기 설정 다시 확인')
              : _photoDateLocked && _pendingSaveFingerprint != null
              ? '저장 결과 다시 확인'
              : _sharePublicly
              ? '기록 저장하고 피드에 공개'
              : '기록 저장',
        ),
      ),
      if (count == 0) ...[
        const SizedBox(height: 8),
        Text(
          '사진을 고르면 저장할 수 있어요.',
          textAlign: TextAlign.center,
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      ],
      if (_savedRecord != null && _sharePublicly) ...[
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('moment-finish-private'),
          onPressed: _busy ? null : _finishPrivately,
          child: const Text('나만 보기로 마치기'),
        ),
      ],
    ],
  );

  Widget _datePolicy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _serverToday == null
            ? '사진을 고를 때 한국 시간 기준 오늘 날짜를 확인해요.'
            : _photoDateLocked
            ? _pendingSaveFingerprint != null
                  ? '이전에 저장을 요청한 내용이에요. 같은 내용으로 저장 결과를 다시 확인할 수 있어요.'
                  : _originalRecord == null
                  ? '날짜가 지난 임시 작성이에요. 사진과 글은 보관되어 있지만 이전 날짜에 새로 저장할 수 없어요.'
                  : '지난 날짜의 사진은 바꿀 수 없어요. 글 수정과 기록 삭제는 가능해요.'
            : '한국 시간 기준 오늘의 사진만 남길 수 있어요. 날짜는 바꿀 수 없어요.',
        key: const ValueKey('moment-photo-date-policy'),
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
      if (_serverToday == null)
        TextButton.icon(
          key: const ValueKey('moment-refresh-server-date'),
          onPressed: _editingLocked ? null : () => _refreshServerDay(),
          icon: const ExperienceIcon('RefreshCw', size: 16),
          label: const Text('오늘 날짜 다시 확인'),
        ),
    ],
  );

  // An unknown date is resolved inside each photo action before any change.
  bool get _photoControlsLocked =>
      _editingLocked || (_serverToday != null && _photoDateLocked);

  Widget _notebookPhotos(BuildContext context, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_changingPhotos)
        Padding(
          key: const ValueKey('moment-photo-change-status'),
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            liveRegion: true,
            label: '사진을 확인하고 있어요',
            excludeSemantics: true,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '사진을 확인하고 있어요',
                    style: ExperienceFormStyle.text(context, 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      for (var i = 0; i < _photos.length; i++)
        _photoTile(
          key: ValueKey(_photos[i].id),
          photoId: _photos[i].id,
          edited: _photos[i].design != null,
          design: _photos[i].design,
          child: MomentPhotoView(
            key: ValueKey('moment-existing-photo-$i'),
            photo: _photos[i],
          ),
        ),
      for (var i = 0; i < _uploads.length; i++)
        _photoTile(
          key: ValueKey(_uploads[i].id),
          photoId: _uploads[i].id,
          edited: _uploads[i].design != null,
          design: _uploads[i].design,
          child: MomentPhotoView(
            key: ValueKey('moment-new-photo-$i'),
            bytes: _uploads[i].bytes,
            design: _uploads[i].design,
          ),
        ),
      if (_removedPhoto != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            liveRegion: true,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('사진을 뺐어요.', style: ExperienceFormStyle.text(context, 12)),
                TextButton.icon(
                  key: const ValueKey('moment-undo-photo-removal'),
                  onPressed: _photoControlsLocked ? null : _undoPhotoRemoval,
                  icon: const ExperienceIcon('Undo2', size: 18),
                  label: const Text('실행 취소'),
                ),
              ],
            ),
          ),
        ),
      if (count < 3) ...[
        _photoEntry(context, count),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('moment-new-photo-format'),
            onPressed: _photoControlsLocked ? null : _selectNewPhotoFormat,
            icon: const ExperienceIcon('Expand', size: 17),
            label: Text('새 사진 규격 · ${_newPhotoCover.displayName}'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              textStyle: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _photoEntry(BuildContext context, int count) => Semantics(
    button: true,
    enabled: !_photoControlsLocked,
    child: InkWell(
      key: const ValueKey('moment-pick-photos'),
      onTap: _photoControlsLocked ? null : _pick,
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(
        builder: (context, box) {
          if (count > 0) {
            return Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: ExperienceFormStyle.line(context)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _picking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ExperienceIcon('ImagePlus', size: 22, color: SocialStyle.accent(context),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _picking ? '사진을 가져오고 있어요' : '사진 더 담기',
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${3 - count}장 더 담을 수 있어요.',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          final stacked =
              box.maxWidth < 270 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final thumbnail = Container(
            width: stacked ? 96 : 108,
            height: stacked ? 96 : 116,
            decoration: BoxDecoration(
              color: SocialStyle.paper(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _picking
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ExperienceIcon('ImagePlus', size: 32, color: SocialStyle.accent(context),
                    ),
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 사진',
                style: ExperienceFormStyle.text(
                  context,
                  16,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _picking
                    ? '사진을 가져오고 있어요'
                    : count == 0
                    ? '아직 고른 사진이 없어요'
                    : '$count장의 사진을 골랐어요',
                style: ExperienceFormStyle.text(context, 12, secondary: true),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _photoControlsLocked
                        ? ExperienceFormStyle.line(context)
                        : SocialStyle.accent(context),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '사진 고르기',
                  style: ExperienceFormStyle.text(
                    context,
                    14,
                    weight: FontWeight.w600,
                    color: _photoControlsLocked
                        ? ExperienceFormStyle.muted(context)
                        : SocialStyle.accent(context),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '1~3장 선택',
                style: ExperienceFormStyle.text(context, 12, secondary: true),
              ),
            ],
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [thumbnail, const SizedBox(height: 12), copy],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    thumbnail,
                    const SizedBox(width: 16),
                    Expanded(child: copy),
                  ],
                );
        },
      ),
    ),
  );

  Widget _shareOptions(BuildContext context) {
    final ids = _availablePhotoIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopupMenuButton<bool>(
          key: const ValueKey('moment-share-public'),
          tooltip: '공개 범위 선택',
          enabled: !_editingLocked,
          initialValue: _sharePublicly,
          onSelected: (value) {
            if (_editingLocked || value == _sharePublicly) return;
            HapticFeedback.selectionClick();
            setState(() {
              _sharePublicly = value;
              _publicPhotoId = value && ids.length == 1 ? ids.single : null;
              _publicationRequestId = const Uuid().v4();
              _error = null;
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              key: ValueKey('moment-privacy-private'),
              value: false,
              child: Row(
                children: [
                  ExperienceIcon('Lock', size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('나만 보기')),
                ],
              ),
            ),
            const PopupMenuItem(
              key: ValueKey('moment-privacy-public'),
              value: true,
              child: Row(
                children: [
                  ExperienceIcon('Globe', size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('피드에도 공개')),
                ],
              ),
            ),
          ],
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: ExperienceFormStyle.line(context)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _sharePublicly
                    ? const ExperienceIcon('Globe', size: 20)
                    : const ExperienceIcon('Lock', size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _sharePublicly ? '피드에도 공개' : '나만 보기',
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const ExperienceIcon('ChevronDown', size: 20),
              ],
            ),
          ),
        ),
        if (_sharePublicly && ids.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '공개할 사진 한 장',
            style: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in ids.indexed)
                ChoiceChip(
                  key: ValueKey('moment-public-photo-${entry.$2}'),
                  label: Text('${entry.$1 + 1}번째 사진'),
                  selected: _publicPhotoId == entry.$2,
                  onSelected: _editingLocked
                      ? null
                      : (_) => setState(() {
                          _publicPhotoId = entry.$2;
                          _publicationRequestId = const Uuid().v4();
                          _error = null;
                        }),
                ),
            ],
          ),
          if (_publicPhotoId != null) ...[
            const SizedBox(height: 12),
            _publicPhotoPreview(),
            if (_caption.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _caption.text.trim(),
                style: ExperienceFormStyle.text(
                  context,
                  13,
                ).copyWith(height: 1.6),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            '다른 사진과 월간 앨범은 공개되지 않아요.',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
        ],
      ],
    );
  }

  Widget _publicPhotoPreview() {
    final photo = _photos
        .where((photo) => photo.id == _publicPhotoId)
        .firstOrNull;
    final upload = _uploads
        .where((photo) => photo.id == _publicPhotoId)
        .firstOrNull;
    if (photo == null && upload == null) return const SizedBox.shrink();
    return ConstrainedBox(
      key: const ValueKey('moment-public-photo-preview'),
      constraints: const BoxConstraints(maxHeight: 240),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: photo != null
            ? MomentPhotoView(photo: photo, fit: BoxFit.contain)
            : MomentPhotoView(
                bytes: upload!.bytes,
                design: upload.design,
                fit: BoxFit.contain,
              ),
      ),
    );
  }

  Widget _existingPublicationStatus() {
    final state = ref
        .watch(momentPublicationStateProvider(_originalRecord!.id))
        .asData
        ?.value;
    if (state?.isPublished != true && state?.isPending != true)
      return const SizedBox.shrink();
    return MomentPublicationPanel(
      record: _originalRecord!,
      allowPublishing: !_dirty && !_busy,
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
    return Padding(
      key: const ValueKey('moment-draft-status'),
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                    : Icons.info_outline_rounded,
                size: 17,
                color: _draftError != null
                    ? Theme.of(context).colorScheme.error
                    : ExperienceFormStyle.muted(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: ExperienceFormStyle.text(
                    context,
                    12,
                    secondary: _draftError == null,
                  ).copyWith(height: 1.5),
                ),
              ),
            ],
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
                  onPressed:
                      _busy ||
                          _picking ||
                          _decorating ||
                          _changingPhotos ||
                          _discarding
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
    required String photoId,
    required bool edited,
    required MomentPhotoDesign? design,
    required Widget child,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: '이 사진 빼기',
                onPressed: _photoControlsLocked
                    ? null
                    : () => _removePhoto(photoId),
                icon: const ExperienceIcon('X'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '규격 · ${design == null ? defaultCoverSize.displayName : momentCoverForDesign(design)?.displayName ?? '기존 사진 비율 유지'}',
            key: ValueKey('moment-photo-format-$photoId'),
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('moment-decorate-$photoId'),
            onPressed: _editingLocked
                ? null
                : () => _decoratePhoto(photoId),
            icon: const ExperienceIcon('Sparkles', size: 18),
            label: Text(edited ? '꾸밈 수정하기' : '사진 꾸미기'),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 48),
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ],
    ),
  );
}
