import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../album/data/browser_draft_database.dart';
import '../domain/moment_draft.dart';
import 'moment_draft_store_base.dart';

MomentDraftStore createPlatformMomentDraftStore() => BrowserMomentDraftStore();

/// The account index contains metadata only. Each original-photo payload lives
/// in a separate record, and both are committed in the same IDB transaction.
/// Recovery cards can therefore list work without copying any photo originals.
class BrowserMomentDraftStore extends MomentDraftStore {
  BrowserMomentDraftStore({String databaseName = 'snapfit_moment_drafts'})
    : _database = BrowserDraftDatabase(databaseName: databaseName);

  final BrowserDraftDatabase _database;
  static const _maximumMetadataBytes = 1024 * 1024;

  String _ownerKey(String owner) =>
      'index:${base64Url.encode(utf8.encode(owner))}';
  String _recordKey(String owner, String recordId) =>
      'draft:${base64Url.encode(utf8.encode(owner))}:${base64Url.encode(utf8.encode(recordId))}';

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MomentDraftException {
      rethrow;
    } catch (_) {
      throw const MomentDraftException(
        '이 브라우저에 임시 저장하지 못했어요. 저장 공간과 브라우저 설정을 확인해 주세요.',
      );
    }
  }

  Future<T> _indexTransaction<T>(
    String owner, {
    required bool write,
    required T Function(
      List<Map<String, dynamic>>,
      void Function(),
      Map<String, JSObject>,
      List<String>,
    )
    action,
  }) {
    validateMomentDraftIdentity(owner);
    final relatedPuts = <String, JSObject>{};
    final relatedRemovals = <String>[];
    return _guard(
      () => _database.transaction<T>(
        owner: _ownerKey(owner),
        write: write,
        additionalPuts: relatedPuts,
        additionalRemovals: relatedRemovals,
        action: (value, put, _) {
          final metadata = <Map<String, dynamic>>[];
          if (value != null) {
            final index = _StoredMomentIndex._(value);
            final json = index.metadata.toDart;
            if (index.owner.toDart != owner ||
                utf8.encode(json).length > _maximumMetadataBytes) {
              throw const FormatException('Invalid draft index');
            }
            metadata.addAll(
              (jsonDecode(json) as List).map(
                (value) => Map<String, dynamic>.from(value as Map),
              ),
            );
          }
          final identities = <String>{};
          for (final entry in metadata) {
            final summary = MomentDraftSummary.fromMetadata(entry);
            if (summary.ownerId != owner || !identities.add(summary.recordId)) {
              throw const FormatException('Invalid draft identity');
            }
          }
          return action(
            metadata,
            () {
              final json = jsonEncode(metadata);
              if (utf8.encode(json).length > _maximumMetadataBytes)
                throw const MomentDraftException('임시 저장할 기록 정보가 너무 커요.');
              put(_StoredMomentIndex(owner: owner.toJS, metadata: json.toJS));
            },
            relatedPuts,
            relatedRemovals,
          );
        },
      ),
    );
  }

  Map<String, dynamic> _metadata(_StoredMomentDraft stored) {
    final json = stored.metadata.toDart;
    if (utf8.encode(json).length > _maximumMetadataBytes)
      throw const FormatException('Draft metadata too large');
    return Map<String, dynamic>.from(jsonDecode(json) as Map);
  }

  MomentDraft _decode(
    String owner,
    String recordId,
    _StoredMomentDraft stored,
  ) {
    final draft = MomentDraft.fromMetadata(
      _metadata(stored),
      photoBytes: stored.photos.toDart.map((photo) => photo.toDart).toList(),
    );
    validateMomentDraft(owner, draft);
    if (draft.version == null || draft.recordId != recordId)
      throw const FormatException('Invalid draft version');
    return draft;
  }

  _StoredMomentDraft _encode(MomentDraft draft) {
    final json = jsonEncode(draft.toMetadata());
    if (utf8.encode(json).length > _maximumMetadataBytes)
      throw const MomentDraftException('임시 저장할 기록 정보가 너무 커요.');
    return _StoredMomentDraft(
      metadata: json.toJS,
      // The domain exposes an unmodifiable Dart view. DDC cannot cast that
      // wrapper to JSUint8Array, and IndexedDB needs a cloneable native array.
      // Snapshot it into a regular typed list at this storage boundary.
      photos: draft.uploads
          .map((photo) => Uint8List.fromList(photo.bytes).toJS)
          .toList()
          .toJS,
    );
  }

  @override
  Future<MomentDraft?> load(String owner, String recordId) {
    validateMomentDraftIdentity(owner, recordId);
    return _guard(
      () => _database.transaction<MomentDraft?>(
        owner: _recordKey(owner, recordId),
        write: false,
        action: (value, _, __) => value == null
            ? null
            : _decode(owner, recordId, _StoredMomentDraft._(value)),
      ),
    );
  }

  @override
  Future<List<MomentDraftSummary>> summaries(String owner) => _indexTransaction(
    owner,
    write: false,
    action: (metadata, _, __, ___) => List.unmodifiable(
      metadata.map(MomentDraftSummary.fromMetadata).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    ),
  );

  @override
  Future<List<MomentDraft>> list(String owner) async {
    final drafts = <MomentDraft>[];
    for (final summary in await summaries(owner)) {
      final draft = await load(owner, summary.recordId);
      // Another tab may have submitted or discarded this record meanwhile.
      if (draft != null) drafts.add(draft);
    }
    return sortedMomentDrafts(drafts);
  }

  @override
  Future<MomentDraft?> latestNew(String owner) async {
    for (final summary in await summaries(owner)) {
      if (summary.isEditing) continue;
      final draft = await load(owner, summary.recordId);
      if (draft != null) return draft;
    }
    return null;
  }

  @override
  Future<MomentDraft> save(
    String owner,
    MomentDraft draft, {
    required String? expectedVersion,
  }) {
    validateMomentDraft(owner, draft);
    return _indexTransaction(
      owner,
      write: true,
      action: (metadata, put, relatedPuts, _) {
        final index = metadata.indexWhere(
          (entry) => entry['recordId'] == draft.recordId,
        );
        final version = index < 0 ? null : metadata[index]['version'];
        if (version != expectedVersion)
          throw const MomentDraftConflictException();
        validateMomentDraftCapacity(
          metadata.map(MomentDraftSummary.fromMetadata),
          draft,
        );
        final saved = draft.copyWith(version: const Uuid().v4());
        if (index < 0) {
          metadata.add(saved.toMetadata());
        } else {
          metadata[index] = saved.toMetadata();
        }
        relatedPuts[_recordKey(owner, draft.recordId)] = _encode(saved);
        put();
        return saved;
      },
    );
  }

  @override
  Future<bool> remove(
    String owner,
    String recordId, {
    required String? expectedVersion,
  }) {
    validateMomentDraftIdentity(owner, recordId);
    return _indexTransaction(
      owner,
      write: true,
      action: (metadata, put, _, relatedRemovals) {
        final index = metadata.indexWhere(
          (entry) => entry['recordId'] == recordId,
        );
        if (index < 0) return false;
        if (metadata[index]['version'] != expectedVersion)
          throw const MomentDraftConflictException();
        metadata.removeAt(index);
        relatedRemovals.add(_recordKey(owner, recordId));
        put();
        return true;
      },
    );
  }
}

extension type _StoredMomentIndex._(JSObject _) implements JSObject {
  external factory _StoredMomentIndex({
    required JSString owner,
    required JSString metadata,
  });
  external JSString get owner;
  external JSString get metadata;
}

extension type _StoredMomentDraft._(JSObject _) implements JSObject {
  external factory _StoredMomentDraft({
    required JSString metadata,
    required JSArray<JSUint8Array> photos,
  });
  external JSString get metadata;
  external JSArray<JSUint8Array> get photos;
}
