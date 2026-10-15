import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../domain/entities/album_creation_draft.dart';
import 'album_creation_draft_store_base.dart';

AlbumCreationDraftStore createAlbumCreationDraftStore() =>
    LocalAlbumCreationDraftStore();

class LocalAlbumCreationDraftStore implements AlbumCreationDraftStore {
  LocalAlbumCreationDraftStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  Future<void> _tail = Future.value();

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
      _serial(() async => _read(await _file(owner)));

  @override
  Future<void> save(String owner, AlbumCreationDraft draft) =>
      _serial(() async {
        final file = await _file(owner);
        await _write(file, draft);
      });

  Future<void> _write(File file, AlbumCreationDraft draft) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.pending');
    await temporary.writeAsString(jsonEncode(draft.toJson()), flush: true);
    await temporary.rename(file.path);
  }

  // Preserve the native queue and identity check when an editor updates a draft.
  @override
  Future<bool> updateLinked(
    String owner,
    String draftId,
    int albumId,
    AlbumCreationDraft Function(AlbumCreationDraft) update,
  ) => _serial(() async {
    final file = await _file(owner);
    final current = await _read(file);
    if (current == null ||
        current.id != draftId ||
        current.createdAlbumId != albumId) {
      return false;
    }
    final next = update(current);
    if (next.id != draftId || next.createdAlbumId != albumId) {
      throw ArgumentError('Linked draft identity cannot change');
    }
    await _write(file, next);
    return true;
  });

  @override
  Future<void> remove(String owner, String draftId) => _serial(() async {
    final file = await _file(owner);
    if ((await _read(file))?.id == draftId) await file.delete();
  });
}
