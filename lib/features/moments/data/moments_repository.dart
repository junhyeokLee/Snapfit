import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/cover_size.dart';
import '../../../core/fonts/document_fonts.dart';
import '../../album/domain/entities/album.dart';
import '../../album/domain/repositories/album_repository.dart';
import '../../billing/data/billing_repository.dart';
import '../domain/moment_record.dart';
import '../domain/moment_photo_design.dart';
import '../domain/monthly_album_builder.dart';
import 'moment_photo_codec.dart';

class MomentUpload {
  const MomentUpload({
    required this.id,
    required this.bytes,
    required this.filename,
    this.design,
  });
  final String id, filename;
  final Uint8List bytes;
  final MomentPhotoDesign? design;

  MomentUpload withDesign(MomentPhotoDesign? value) =>
      MomentUpload(id: id, bytes: bytes, filename: filename, design: value);
}

abstract class MomentsRepository {
  String? get currentUserId;
  Stream<String?> get authChanges;

  /// null은 기기 날짜와 무관하게 서버가 선택한 현재 월을 읽는다.
  Future<MomentJournal> listMonth(DateTime? month);
  Future<MomentRecord> save({
    required String id,
    required DateTime recordDate,
    required String caption,
    required List<MomentPhoto> existingPhotos,
    required List<MomentUpload> uploads,
    List<MomentPhoto> originalPhotos = const [],
    int? expectedRevision,
  });
  Future<void> delete(MomentRecord record);
  Future<Album> fetchAlbum(int id);
  Future<Album> appendMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
  });
  Future<Album> createMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
    required String title,
  });
}

class SupabaseMomentsRepository implements MomentsRepository {
  SupabaseMomentsRepository(
    this.client, {
    required this.albums,
    required this.billing,
    Future<void> Function()? prepareMonthlyFonts,
  }) : _prepareMonthlyFonts = prepareMonthlyFonts ?? _prepareFonts {
    _actor = currentUserId;
    _subscription = client.auth.onAuthStateChange.listen(
      (state) {
        final next = state.session?.user.id;
        if (next != _actor) {
          _actor = next;
          _revision++;
        }
      },
      onError: (Object _, StackTrace __) {
        // A failed/offline refresh invalidates pending work without becoming
        // an unhandled auth-stream error or accepting an obsolete response.
        _revision++;
      },
    );
  }
  final SupabaseClient client;
  final AlbumRepository albums;
  final BillingRepository billing;
  final Future<void> Function() _prepareMonthlyFonts;
  static Future<void> _prepareFonts() =>
      DocumentFonts.ensure(monthlyMomentFontFamilies);
  late final StreamSubscription<AuthState> _subscription;
  String? _actor;
  int _revision = 0;

  @override
  String? get currentUserId => client.auth.currentUser?.id;
  @override
  Stream<String?> get authChanges => client.auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();

  (String, int) _session() {
    final id = currentUserId;
    if (id == null) throw const MomentException('로그인 후 나의 기록을 남길 수 있어요.');
    return (id, _revision);
  }

  void _check((String, int) session) {
    if (session.$1 != currentUserId || session.$2 != _revision) {
      throw const MomentException('계정이 변경됐어요. 나의 기록을 다시 열어 주세요.');
    }
  }

  Future<dynamic> _rpc(
    String name,
    Map<String, dynamic> params,
    (String, int) session,
  ) async {
    _check(session);
    try {
      final result = await client
          .rpc(name, params: params)
          .timeout(const Duration(seconds: 25));
      _check(session);
      return result;
    } on PostgrestException catch (error) {
      _check(session);
      throw MomentException(momentServerError(error.message, error.code));
    } on TimeoutException {
      _check(session);
      throw const MomentException('연결이 지연되고 있어요. 다시 시도하면 저장 여부를 확인해요.');
    }
  }

  @override
  Future<MomentJournal> listMonth(DateTime? month) async {
    final session = _session();
    final raw = await _rpc('get_moment_journal', {
      'p_month': month == null ? null : momentDateKey(momentMonth(month)),
    }, session);
    // Images resolve lazily through SnapfitImage's session-aware cache. A
    // preview request must not block the journal or hide its captions/actions.
    return MomentJournal.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<MomentRecord> save({
    required String id,
    required DateTime recordDate,
    required String caption,
    required List<MomentPhoto> existingPhotos,
    required List<MomentUpload> uploads,
    List<MomentPhoto> originalPhotos = const [],
    int? expectedRevision,
  }) async {
    final session = _session();
    try {
      final saved = await _save(
        id: id,
        recordDate: recordDate,
        caption: caption,
        existingPhotos: existingPhotos,
        uploads: uploads,
        expectedRevision: expectedRevision,
      );
      final retained = saved.photos.map((photo) => photo.path).toSet();
      await _removeUnusedPhotos(
        originalPhotos
            .map((photo) => photo.path)
            .where((path) => !retained.contains(path)),
        session,
      );
      _check(session);
      return saved;
    } catch (_) {
      await _removeUnusedPhotos(
        uploads.map((photo) => '${session.$1}/moments/$id/${photo.id}.png'),
        session,
      );
      rethrow;
    }
  }

  Future<MomentRecord> _save({
    required String id,
    required DateTime recordDate,
    required String caption,
    required List<MomentPhoto> existingPhotos,
    required List<MomentUpload> uploads,
    int? expectedRevision,
  }) async {
    final session = _session();
    final identifier = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );
    if (!identifier.hasMatch(id) ||
        uploads.any((photo) => !identifier.hasMatch(photo.id))) {
      throw const MomentException('기록 정보를 확인하지 못했어요. 화면을 다시 열어 주세요.');
    }
    final photoCount = existingPhotos.length + uploads.length;
    if (photoCount < 1 || photoCount > 3) {
      throw const MomentException('기록마다 사진 1~3장을 골라 주세요.');
    }
    if (caption.trim().runes.length > 200)
      throw const MomentException('기록은 200자까지 남길 수 있어요.');
    final ids = [
      ...existingPhotos.map((photo) => photo.id),
      ...uploads.map((photo) => photo.id),
    ];
    if (ids.toSet().length != ids.length)
      throw const MomentException('같은 사진이 두 번 선택됐어요.');
    final photos = <MomentPhoto>[...existingPhotos];
    for (final upload in uploads) {
      final prepared = await prepareMomentPhoto(upload.bytes);
      _check(session);
      final path = '${session.$1}/moments/$id/${upload.id}.png';
      final quota = await billing.preflightStorage(
        incomingBytes: prepared.bytes.length,
      );
      _check(session);
      if (!quota.allowed) {
        // A previous attempt may already have uploaded this exact object. Its
        // bytes are counted in the quota, so a retry must not charge them twice.
        var alreadyUploaded = false;
        try {
          final old = await client.storage.from('album-assets').download(path);
          _check(session);
          alreadyUploaded =
              sha256.convert(old) == sha256.convert(prepared.bytes);
        } on StorageException {
          _check(session);
        }
        if (!alreadyUploaded) {
          throw const MomentException('저장 공간이 부족해요. 설정에서 저장 공간을 확인해 주세요.');
        }
        photos.add(
          MomentPhoto(
            id: upload.id,
            path: path,
            width: prepared.width,
            height: prepared.height,
            design: upload.design,
          ),
        );
        continue;
      }
      try {
        await client.storage
            .from('album-assets')
            .uploadBinary(
              path,
              prepared.bytes,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: false,
              ),
            );
      } on StorageException catch (error) {
        _check(session);
        if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
        // Retries reuse an immutable object. Never overwrite a photo that a
        // previous request may already have committed to a record or album.
        final old = await client.storage.from('album-assets').download(path);
        _check(session);
        if (sha256.convert(old) != sha256.convert(prepared.bytes)) {
          throw const MomentException('사진이 변경됐어요. 사진을 다시 선택해 주세요.');
        }
      }
      _check(session);
      photos.add(
        MomentPhoto(
          id: upload.id,
          path: path,
          width: prepared.width,
          height: prepared.height,
          design: upload.design,
        ),
      );
    }
    final raw = await _rpc('save_weekly_moment', {
      'p_id': id,
      'p_record_date': momentDateKey(recordDate),
      'p_caption': caption.trim(),
      'p_photos': photos.map((photo) => photo.toJson()).toList(),
      'p_expected_revision': expectedRevision ?? 0,
    }, session);
    return MomentRecord.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<void> delete(MomentRecord record) async {
    final session = _session();
    await _rpc('delete_weekly_moment', {
      'p_id': record.id,
      'p_expected_revision': record.revision,
    }, session);
    await _removeUnusedPhotos(
      record.photos.map((photo) => photo.path),
      session,
    );
    _check(session);
  }

  Future<void> _removeUnusedPhotos(
    Iterable<String> paths,
    (String, int) session,
  ) async {
    final safePath = RegExp(
      '^${RegExp.escape(session.$1)}/moments/'
      r'[0-9a-f-]{36}/[0-9a-f-]{36}\.(png|jpg|jpeg|webp)$',
    );
    for (final path in paths.toSet()) {
      if (session.$1 != currentUserId || session.$2 != _revision) return;
      if (!safePath.hasMatch(path)) continue;
      try {
        // Storage's row locks and record/album reference guards are the final
        // authority, including when an earlier save response was lost.
        await client.storage
            .from('album-assets')
            .remove([path])
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // A referenced original must remain. Cleanup failures never turn a
        // confirmed journal mutation into an apparent failed save/delete.
      }
    }
  }

  @override
  Future<Album> fetchAlbum(int id) async {
    final session = _session();
    final album = await albums.fetchAlbum('$id');
    _check(session);
    return album;
  }

  @override
  Future<Album> createMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
    required String title,
  }) async {
    final session = _session();
    await _prepareMonthlyFonts();
    await DocumentFonts.ensure({
      for (final record in selectedRecords)
        for (final photo in record.photos) ...?photo.design?.fontFamilies,
    });
    _check(session);
    final request = buildMonthlyMomentAlbum(
      month: month,
      records: selectedRecords,
      selectedPhotoIds: selectedPhotoIds,
      title: title,
    );
    final raw = await _rpc('create_moment_month_album', {
      'p_month': momentDateKey(momentMonth(month)),
      'p_photo_ids': selectedPhotoIds,
      'p_album': {
        'title': request.title,
        'ratio': request.ratio,
        'cover_layers_json': request.coverLayersJson,
        'cover_image_url': request.coverImageUrl,
        'cover_thumbnail_url': request.coverThumbnailUrl,
        'cover_original_url': request.coverOriginalUrl,
        'cover_preview_url': request.coverPreviewUrl,
        'cover_theme': request.coverTheme,
        'target_pages': request.targetPages,
        'total_pages': request.targetPages,
      },
    }, session);
    final id = ((raw as Map)['albumId'] as num).toInt();
    final album = await albums.fetchAlbum('$id');
    _check(session);
    return album;
  }

  @override
  Future<Album> appendMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
  }) async {
    final session = _session();
    await DocumentFonts.ensure({
      for (final record in selectedRecords)
        for (final photo in record.photos) ...?photo.design?.fontFamilies,
    });
    _check(session);
    final journal = await listMonth(month);
    _check(session);
    final albumId = journal.monthlyAlbumId;
    if (albumId == null)
      throw const MomentException('이달의 앨범이 없어졌어요. 기록에서 다시 만들어 주세요.');
    final album = await fetchAlbum(albumId);
    _check(session);
    final pending = selectedPhotoIds
        .where((id) => !journal.monthlyAlbumPhotoIds.contains(id))
        .toList(growable: false);
    if (pending.isEmpty) return album;
    await _prepareMonthlyFonts();
    _check(session);
    final pages = buildMonthlyMomentAppendPages(
      month: month,
      records: selectedRecords,
      selectedPhotoIds: pending,
      canvasSize: coverCanvasBaseSize(album.physicalCoverSize),
    );
    await _rpc('append_moment_month_album', {
      'p_month': momentDateKey(momentMonth(month)),
      'p_album_id': albumId,
      'p_photo_ids': pending,
      'p_pages': pages,
      'p_expected_updated_at': album.updatedAt,
    }, session);
    final latest = await fetchAlbum(albumId);
    _check(session);
    return latest;
  }

  void dispose() => unawaited(_subscription.cancel());
}

String momentServerError(String message, String? code) {
  message = message.toLowerCase();
  if (message.contains('day_locked') ||
      message.contains('day_changed') ||
      message.contains('past_photo') ||
      message.contains('today_only') ||
      message.contains('record_date_immutable')) {
    return '사진은 한국 시간 기준 당일에만 추가하거나 바꿀 수 있어요. 지난 기록은 글만 수정할 수 있어요.';
  }
  if (message.contains('design_material_unavailable')) {
    return '선택한 꾸미기 소재의 사용 권한을 확인해 주세요. 사진을 열어 소재를 다시 골라 주세요.';
  }
  if (message.contains('invalid_design')) {
    return '꾸민 사진 정보를 확인하지 못했어요. 사진을 다시 열어 적용해 주세요.';
  }
  if (message.contains('month_full'))
    return '한 달에 기록을 100개까지 남길 수 있어요. 기존 기록을 다듬어 주세요.';
  if (message.contains('album_full'))
    return '앨범은 80쪽까지 담을 수 있어요. 기존 앨범에서 페이지를 정리해 주세요.';
  if (message.contains('album_locked'))
    return '다른 사람이 앨범을 편집 중이에요. 편집이 끝난 뒤 다시 추가해 주세요.';
  if (message.contains('album_changed'))
    return '앨범이 변경됐어요. 미리보기를 다시 열어 새 사진을 골라 주세요.';
  if (message.contains('selection_changed'))
    return '선택한 사진의 기록이 바뀌었어요. 목록을 새로고침한 뒤 다시 골라 주세요.';
  if (message.contains('revision') || code == 'PT409') {
    return '다른 곳에서 수정된 기록이에요. 목록을 새로고침한 뒤 다시 열어 주세요.';
  }
  if (message.contains('future') ||
      message.contains('date') ||
      message.contains('invalid_month'))
    return '기록 날짜를 확인해 주세요. 사진은 한국 시간 기준 오늘에만 남길 수 있어요.';
  if (message.contains('photo') || message.contains('asset'))
    return '사진을 확인하지 못했어요. 목록을 새로고침하고 다시 시도해 주세요.';
  if (message.contains('auth') || code == '42501')
    return '로그인 상태와 기록의 접근 권한을 확인해 주세요.';
  if (message.contains('limit')) return '저장 가능한 기록 수를 넘었어요. 기존 기록을 확인해 주세요.';
  return '기록을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.';
}
