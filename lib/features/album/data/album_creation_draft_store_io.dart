import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/entities/album_creation_draft.dart';
import 'album_creation_draft_store_base.dart';

AlbumCreationDraftStore createAlbumCreationDraftStore() =>
    LocalAlbumCreationDraftStore();

class LocalAlbumCreationDraftStore
    implements AlbumCreationDraftStore, AlbumCreationDraftWriteSession {
  LocalAlbumCreationDraftStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  Future<void> _tail = Future.value();
  final Map<(String, String), String?> _writeBaselines = {};
  static final Map<String, Future<void>> _fileOperations = {};

  String? _revision(AlbumCreationDraft? draft) => draft == null
      ? null
      : sha256.convert(utf8.encode(jsonEncode(draft.toJson()))).toString();

  void _checkBaseline(String owner, String id, AlbumCreationDraft? current) {
    final key = (owner, id);
    if (_writeBaselines.containsKey(key) &&
        _writeBaselines[key] != _revision(current)) {
      throw StateError('The saved creation draft changed in another editor.');
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<File> _file(String owner) async {
    if (owner.trim().isEmpty) throw ArgumentError('Draft owner is required');
    final root = await _directory();
    final key = base64Url.encode(utf8.encode(owner));
    return File('${root.path}/album_creation_drafts/$key.json');
  }

  Future<T> _locked<T>(
    String owner,
    Future<T> Function(File file) action,
  ) async {
    final file = await _file(owner);
    // POSIX record locks are process-scoped, so serialize separate store
    // instances here as well as locking other processes on a stable file.
    final previous = _fileOperations[file.path];
    final released = Completer<void>();
    _fileOperations[file.path] = released.future;
    RandomAccessFile? lock;
    var locked = false;
    try {
      if (previous != null) await previous;
      final lockFile = File(
        '${file.parent.parent.path}/album_creation_draft_locks/'
        '${file.uri.pathSegments.last}.lock',
      );
      await lockFile.parent.create(recursive: true);
      lock = await lockFile.open(mode: FileMode.append);
      await lock.lock(FileLock.blockingExclusive);
      locked = true;
      return await action(file);
    } finally {
      try {
        if (locked) await lock?.unlock();
      } finally {
        try {
          await lock?.close();
        } finally {
          released.complete();
          if (identical(_fileOperations[file.path], released.future)) {
            _fileOperations.remove(file.path);
          }
        }
      }
    }
  }

  Future<AlbumCreationDraft?> _read(File file) async {
    if (!await file.exists()) return null;
    if (await file.length() > 32 * 1024 * 1024)
      throw const FormatException('Draft is too large');
    return AlbumCreationDraft.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  @override
  Future<AlbumCreationDraft?> load(String owner) =>
      _serial(() => _locked(owner, _read));

  @override
  Future<void> save(String owner, AlbumCreationDraft draft) => _serial(
    () => _locked(owner, (file) async {
      _checkBaseline(owner, draft.id, await _read(file));
      if (draft.creationAttempt != null &&
          draft.creationAttempt!.ownerId != owner) {
        throw ArgumentError('Creation attempt owner cannot change');
      }
      await _write(file, draft);
      _writeBaselines[(owner, draft.id)] = _revision(draft);
    }),
  );

  @override
  Future<void> beginDraftWriteSession(
    String owner,
    String draftId, {
    AlbumCreationDraft? restoring,
  }) => _serial(
    () => _locked(owner, (file) async {
      final current = await _read(file);
      if (draftId.isEmpty || restoring != null && restoring.id != draftId) {
        throw ArgumentError('Draft identity cannot change');
      }
      if (restoring != null && _revision(restoring) != _revision(current)) {
        throw StateError('The restored creation draft has changed.');
      }
      _writeBaselines[(owner, draftId)] = _revision(current);
    }),
  );

  Future<void> _write(File file, AlbumCreationDraft draft) async {
    final json = jsonEncode(draft.toJson());
    if (utf8.encode(json).length > 32 * 1024 * 1024) {
      throw const FormatException('Draft is too large');
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.pending');
    await temporary.writeAsString(json, flush: true);
    await temporary.rename(file.path);
  }

  // Preserve the native queue and identity check when an editor updates a draft.
  @override
  Future<bool> updateLinked(
    String owner,
    String draftId,
    int albumId,
    AlbumCreationDraft Function(AlbumCreationDraft) update,
  ) => _serial(
    () => _locked(owner, (file) async {
      final current = await _read(file);
      if (current == null ||
          current.id != draftId ||
          current.createdAlbumId != albumId) {
        return false;
      }
      _checkBaseline(owner, draftId, current);
      final next = update(current);
      if (next.id != draftId || next.createdAlbumId != albumId) {
        throw ArgumentError('Linked draft identity cannot change');
      }
      await _write(file, next);
      _writeBaselines[(owner, draftId)] = _revision(next);
      return true;
    }),
  );

  @override
  Future<void> remove(String owner, String draftId) => _serial(
    () => _locked(owner, (file) async {
      final current = await _read(file);
      if (current?.id != draftId) return;
      _checkBaseline(owner, draftId, current);
      await file.delete();
      _writeBaselines[(owner, draftId)] = null;
    }),
  );
}
