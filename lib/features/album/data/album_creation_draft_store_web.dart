import 'dart:convert';
import 'dart:js_interop';

import 'package:photo_manager/photo_manager.dart';

import '../domain/entities/album_creation_draft.dart';
import '../domain/entities/layer.dart';
import 'album_creation_draft_store_base.dart';
import 'browser_draft_database.dart';
import 'gallery/browser_photo_asset.dart';

AlbumCreationDraftStore createAlbumCreationDraftStore() =>
    BrowserAlbumCreationDraftStore();

/// One atomic record per account keeps the document and all referenced
/// originals together. No base64 copy, local filesystem, or new cloud service.
class BrowserAlbumCreationDraftStore
    implements AlbumCreationDraftStore, AlbumCreationDraftWriteSession {
  final _database = BrowserDraftDatabase();
  Future<void> _tail = Future.value();
  final Map<_BrowserDraftWriteKey, _BrowserDraftRevision?> _writeBaselines = {};

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  _StoredBrowserDraft _encode(String owner, AlbumCreationDraft draft) {
    if (owner.trim().isEmpty) throw ArgumentError('Draft owner is required');
    final json = jsonEncode(draft.toJson());
    if (utf8.encode(json).length > 32 * 1024 * 1024) {
      throw const BrowserPhotoException('임시 저장할 앨범 정보가 너무 커요.');
    }
    final photos = <String, BrowserPhotoAsset>{};
    void addPhoto(AssetEntity? photo) {
      if (photo == null) return;
      if (photo is! BrowserPhotoAsset || photo.ownerId != owner) {
        throw const BrowserPhotoException('임시 저장할 사진 원본을 다시 선택해주세요.');
      }
      final existing = photos[photo.id];
      if (existing != null && existing.contentSha256 != photo.contentSha256) {
        throw const BrowserPhotoException('사진 원본 정보가 일치하지 않아요.');
      }
      photos[photo.id] = photo;
    }
    void addPages(List<List<LayerModel>>? pages) {
      if (pages == null) return;
      for (final page in pages) {
        for (final layer in page) {
          addPhoto(layer.asset);
        }
      }
    }
    for (final photo in draft.pendingPhotos) {
      addPhoto(photo);
    }
    addPages(draft.pages);
    addPages(draft.basePages);
    for (final pages in draft.variants?.values ??
        const <List<List<LayerModel>>>[]) {
      addPages(pages);
    }
    if (draft.editedCover != null) addPages([draft.editedCover!]);
    addPages(draft.editorCheckpoint?.pages.map((page) => page.layers).toList());
    // Selection-library limits do not cap an entire book assembled in batches.
    // IndexedDB reports insufficient space atomically without replacing a draft.
    return _StoredBrowserDraft(
      owner: owner.toJS,
      json: json.toJS,
      photos: photos.values.map((photo) => _StoredBrowserPhoto(
        id: photo.id.toJS,
        name: (photo.title ?? '사진').toJS,
        width: photo.width.toJS,
        height: photo.height.toJS,
        createdAtSecond: (photo.createDateSecond ?? 0).toJS,
        contentSha256: photo.contentSha256.toJS,
        original: photo.originalBytes.toJS,
        preview: photo.previewBytes.toJS,
      )).toList().toJS,
    );
  }

  Map<String, dynamic> _metadata(String owner, JSObject value) {
    final record = _StoredBrowserDraft._(value);
    final json = record.json.toDart;
    if (record.owner.toDart != owner ||
        utf8.encode(json).length > 32 * 1024 * 1024) {
      throw const BrowserPhotoException('임시 저장한 앨범 정보를 확인하지 못했어요.');
    }
    return Map<String, dynamic>.from(jsonDecode(json) as Map);
  }

  static const _staleWrite = BrowserPhotoException(
    '다른 창에서 임시 저장한 내용이 변경되었어요. 이 화면을 다시 열어 최신 앨범을 확인해주세요.',
  );

  _BrowserDraftRevision? _revision(String owner, JSObject? value) {
    if (value == null) return null;
    final metadata = _metadata(owner, value);
    final id = metadata['id'];
    final updatedAt = metadata['updatedAt'];
    final createdAlbumId = metadata['createdAlbumId'];
    final timestamp = updatedAt is String ? DateTime.tryParse(updatedAt) : null;
    if (id is! String ||
        id.isEmpty ||
        timestamp == null ||
        (createdAlbumId != null && createdAlbumId is! int)) {
      throw const BrowserPhotoException('임시 저장한 앨범 정보를 확인하지 못했어요.');
    }
    return (
      id: id,
      updatedAtMicros: timestamp.toUtc().microsecondsSinceEpoch,
      createdAlbumId: createdAlbumId as int?,
    );
  }

  _BrowserDraftRevision _draftRevision(AlbumCreationDraft draft) => (
    id: draft.id,
    updatedAtMicros: draft.updatedAt.toUtc().microsecondsSinceEpoch,
    createdAlbumId: draft.createdAlbumId,
  );

  @override
  Future<void> beginDraftWriteSession(
    String owner,
    String draftId, {
    AlbumCreationDraft? restoring,
  }) => _serial(() async {
    if (owner.trim().isEmpty || draftId.trim().isEmpty) {
      throw ArgumentError('Draft owner and identity are required');
    }
    if (restoring != null && restoring.id != draftId) {
      throw ArgumentError('Restored draft identity cannot change');
    }
    final revision = await _database.transaction<_BrowserDraftRevision?>(
      owner: owner,
      write: false,
      action: (value, _, __) {
        final current = _revision(owner, value);
        if (restoring != null && current != _draftRevision(restoring)) {
          throw _staleWrite;
        }
        return current;
      },
    );
    _writeBaselines[(owner: owner, draftId: draftId)] = revision;
  });

  AlbumCreationDraft _decode(String owner, JSObject value) {
    final metadata = _metadata(owner, value);
    final stored = _StoredBrowserDraft._(value).photos.toDart;
    final photos = <String, BrowserPhotoAsset>{};
    for (final photo in stored) {
      final original = photo.original.toDart;
      if (photos.containsKey(photo.id.toDart)) {
        throw const BrowserPhotoException('임시 저장한 사진 원본을 확인하지 못했어요.');
      }
      final restored = BrowserPhotoAsset.fromStored(
        ownerId: owner,
        id: photo.id.toDart,
        name: photo.name.toDart,
        width: photo.width.toDartInt,
        height: photo.height.toDartInt,
        createdAtSecond: photo.createdAtSecond.toDartInt,
        originalBytes: original,
        previewBytes: photo.preview.toDart,
        contentSha256: photo.contentSha256.toDart,
      );
      photos[restored.id] = restored;
    }
    return AlbumCreationDraft.fromJson(metadata, photoDecoder: (reference) {
      final photo = photos[reference['id']];
      if (photo == null ||
          photo.width != reference['width'] ||
          photo.height != reference['height']) {
        throw const BrowserPhotoException('임시 저장한 사진 원본을 찾지 못했어요.');
      }
      return photo;
    });
  }

  @override
  Future<AlbumCreationDraft?> load(String owner) => _serial(() =>
    _database.transaction<AlbumCreationDraft?>(
      owner: owner,
      write: false,
      action: (value, _, __) => value == null ? null : _decode(owner, value),
    ),
  );

  @override
  Future<void> save(String owner, AlbumCreationDraft draft) => _serial(() async {
    final key = (owner: owner, draftId: draft.id);
    if (!_writeBaselines.containsKey(key)) throw _staleWrite;
    final baseline = _writeBaselines[key];
    final record = _encode(owner, draft);
    await _database.transaction<void>(
      owner: owner,
      write: true,
      action: (value, put, _) {
        if (_revision(owner, value) != baseline) throw _staleWrite;
        put(record);
      },
    );
    // Quota errors and aborted transactions leave the previous baseline intact.
    _writeBaselines[key] = _draftRevision(draft);
  });

  // The read, identity check, and replacement share a readwrite transaction,
  // so an older editor/tab cannot recreate a deleted or replaced draft.
  @override
  Future<bool> updateLinked(
    String owner,
    String draftId,
    int albumId,
    AlbumCreationDraft Function(AlbumCreationDraft) update,
  ) => _serial(() async {
    final key = (owner: owner, draftId: draftId);
    if (!_writeBaselines.containsKey(key)) throw _staleWrite;
    final baseline = _writeBaselines[key];
    final revision = await _database.transaction<_BrowserDraftRevision?>(
      owner: owner,
      write: true,
      action: (value, put, _) {
        if (_revision(owner, value) != baseline) {
          throw _staleWrite;
        }
        if (value == null) return null;
        final current = _decode(owner, value);
        if (current.id != draftId || current.createdAlbumId != albumId) {
          return null;
        }
        final next = update(current);
        if (next.id != draftId || next.createdAlbumId != albumId) {
          throw ArgumentError('Linked draft identity cannot change');
        }
        put(_encode(owner, next));
        return _draftRevision(next);
      },
    );
    if (revision == null) return false;
    _writeBaselines[key] = revision;
    return true;
  });

  @override
  Future<void> remove(String owner, String draftId) => _serial(() =>
    _database.transaction<void>(
      owner: owner,
      write: true,
      action: (value, _, remove) {
        final key = (owner: owner, draftId: draftId);
        if (!_writeBaselines.containsKey(key) ||
            _revision(owner, value) != _writeBaselines[key]) {
          throw _staleWrite;
        }
        if (value != null && _metadata(owner, value)['id'] == draftId) remove();
      },
    ),
  );
}

typedef _BrowserDraftWriteKey = ({String owner, String draftId});
typedef _BrowserDraftRevision = ({
  String id,
  int updatedAtMicros,
  int? createdAlbumId,
});

extension type _StoredBrowserDraft._(JSObject _) implements JSObject {
  external factory _StoredBrowserDraft({
    required JSString owner,
    required JSString json,
    required JSArray<_StoredBrowserPhoto> photos,
  });
  external JSString get owner;
  external JSString get json;
  external JSArray<_StoredBrowserPhoto> get photos;
}

extension type _StoredBrowserPhoto._(JSObject _) implements JSObject {
  external factory _StoredBrowserPhoto({
    required JSString id,
    required JSString name,
    required JSNumber width,
    required JSNumber height,
    required JSNumber createdAtSecond,
    required JSString contentSha256,
    required JSUint8Array original,
    required JSUint8Array preview,
  });
  external JSString get id;
  external JSString get name;
  external JSNumber get width;
  external JSNumber get height;
  external JSNumber get createdAtSecond;
  external JSString get contentSha256;
  external JSUint8Array get original;
  external JSUint8Array get preview;
}
