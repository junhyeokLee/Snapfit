import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/moment_draft.dart';
import 'moment_draft_store_base.dart';

MomentDraftStore createPlatformMomentDraftStore() => LocalMomentDraftStore();

/// A record and its original photo bytes commit in one atomic file replacement.
/// The process queue plus an OS file lock serializes CAS across store instances.
class LocalMomentDraftStore extends MomentDraftStore {
  LocalMomentDraftStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  static Future<void> _tail = Future.value();
  static const _maximumMetadataBytes = 1024 * 1024;
  static const _maximumFileBytes =
      3 * momentDraftMaximumPhotoBytes + _maximumMetadataBytes + 4;

  Future<T> _locked<T>(String owner, Future<T> Function(Directory) action) {
    final result = _tail.then((_) async {
      validateMomentDraftIdentity(owner);
      try {
        final root = await _directory();
        final key = base64Url.encode(utf8.encode(owner));
        final folder = Directory('${root.path}/moment_drafts/$key');
        await folder.create(recursive: true);
        final lock = await File(
          '${folder.path}/.lock',
        ).open(mode: FileMode.append);
        try {
          await lock.lock(FileLock.blockingExclusive);
          return await action(folder);
        } finally {
          try {
            await lock.unlock();
          } finally {
            await lock.close();
          }
        }
      } on MomentDraftException {
        rethrow;
      } catch (_) {
        throw const MomentDraftException(
          '기기에 임시 저장하지 못했어요. 저장 공간을 확인한 뒤 다시 시도해 주세요.',
        );
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  File _file(Directory folder, String recordId) =>
      File('${folder.path}/${base64Url.encode(utf8.encode(recordId))}.draft');

  Future<MomentDraftSummary?> _summary(String owner, File file) async {
    if (!await file.exists()) return null;
    final length = await file.length();
    if (length < 4 || length > _maximumFileBytes) {
      throw const MomentDraftException('기기에 남긴 기록을 읽지 못했어요. 원본은 지우지 않고 보관했어요.');
    }
    final input = await file.open();
    try {
      final header = await input.read(4);
      if (header.length != 4)
        throw const FormatException('Missing draft header');
      final count = ByteData.sublistView(header).getUint32(0);
      if (count > _maximumMetadataBytes || count + 4 > length) {
        throw const FormatException('Invalid draft metadata length');
      }
      final bytes = await input.read(count);
      if (bytes.length != count)
        throw const FormatException('Incomplete draft metadata');
      final metadata = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      final summary = MomentDraftSummary.fromMetadata(metadata);
      if (summary.ownerId != owner ||
          _file(file.parent, summary.recordId).path != file.path ||
          4 + count + summary.photoBytes != length) {
        throw const FormatException('Invalid draft identity');
      }
      return summary;
    } catch (_) {
      throw const MomentDraftException('기기에 남긴 기록을 읽지 못했어요. 원본은 지우지 않고 보관했어요.');
    } finally {
      await input.close();
    }
  }

  Future<List<MomentDraftSummary>> _summaries(
    String owner,
    Directory folder,
  ) async {
    final summaries = <MomentDraftSummary>[];
    await for (final entity in folder.list()) {
      if (entity is! File || !entity.path.endsWith('.draft')) continue;
      final summary = await _summary(owner, entity);
      if (summary != null) summaries.add(summary);
    }
    return List.unmodifiable(
      summaries..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }

  Future<MomentDraft?> _read(String owner, File file) async {
    if (!await file.exists()) return null;
    final length = await file.length();
    if (length < 4 || length > _maximumFileBytes) {
      throw const MomentDraftException('기기에 남긴 기록을 읽지 못했어요. 원본은 지우지 않고 보관했어요.');
    }
    final input = await file.open();
    try {
      final header = await input.read(4);
      if (header.length != 4)
        throw const FormatException('Missing draft header');
      final metadataLength = ByteData.sublistView(header).getUint32(0);
      if (metadataLength > _maximumMetadataBytes ||
          metadataLength + 4 > length) {
        throw const FormatException('Invalid draft metadata length');
      }
      final metadataBytes = await input.read(metadataLength);
      if (metadataBytes.length != metadataLength)
        throw const FormatException('Incomplete draft');
      final metadata = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(metadataBytes)) as Map,
      );
      final uploads = metadata['uploads'] as List;
      if (uploads.length > 3)
        throw const FormatException('Too many draft photos');
      final photos = <Uint8List>[];
      var consumed = metadataLength + 4;
      for (final raw in uploads) {
        final count = (raw as Map)['length'];
        if (count is! int ||
            count <= 0 ||
            count > momentDraftMaximumPhotoBytes ||
            consumed + count > length) {
          throw const FormatException('Invalid draft photo length');
        }
        final bytes = await input.read(count);
        if (bytes.length != count)
          throw const FormatException('Incomplete draft photo');
        photos.add(bytes);
        consumed += count;
      }
      if (consumed != length)
        throw const FormatException('Unexpected draft bytes');
      final draft = MomentDraft.fromMetadata(metadata, photoBytes: photos);
      validateMomentDraft(owner, draft);
      if (draft.version == null ||
          _file(file.parent, draft.recordId).path != file.path) {
        throw const FormatException('Invalid draft identity');
      }
      return draft;
    } on MomentDraftException {
      rethrow;
    } catch (_) {
      throw const MomentDraftException('기기에 남긴 기록을 읽지 못했어요. 원본은 지우지 않고 보관했어요.');
    } finally {
      await input.close();
    }
  }

  Future<void> _write(File file, MomentDraft draft) async {
    final metadata = utf8.encode(jsonEncode(draft.toMetadata()));
    if (metadata.length > _maximumMetadataBytes) {
      throw const MomentDraftException('임시 저장할 기록 정보가 너무 커요.');
    }
    final temporary = File('${file.path}.${const Uuid().v4()}.pending');
    try {
      final output = await temporary.open(mode: FileMode.write);
      try {
        final header = ByteData(4)..setUint32(0, metadata.length);
        await output.writeFrom(header.buffer.asUint8List());
        await output.writeFrom(metadata);
        for (final photo in draft.uploads) {
          await output.writeFrom(photo.bytes);
        }
        await output.flush();
      } finally {
        await output.close();
      }
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<MomentDraft?> load(String owner, String recordId) {
    validateMomentDraftIdentity(owner, recordId);
    return _locked(owner, (folder) => _read(owner, _file(folder, recordId)));
  }

  @override
  Future<List<MomentDraft>> list(String owner) =>
      _locked(owner, (folder) async {
        final drafts = <MomentDraft>[];
        await for (final entity in folder.list()) {
          if (entity is! File || !entity.path.endsWith('.draft')) continue;
          final draft = await _read(owner, entity);
          if (draft != null) drafts.add(draft);
        }
        return sortedMomentDrafts(drafts);
      });

  @override
  Future<List<MomentDraftSummary>> summaries(String owner) =>
      _locked(owner, (folder) => _summaries(owner, folder));

  @override
  Future<MomentDraft?> latestNew(String owner) =>
      _locked(owner, (folder) async {
        for (final summary in await _summaries(owner, folder)) {
          if (!summary.isEditing)
            return _read(owner, _file(folder, summary.recordId));
        }
        return null;
      });

  @override
  Future<MomentDraft> save(
    String owner,
    MomentDraft draft, {
    required String? expectedVersion,
  }) {
    validateMomentDraft(owner, draft);
    return _locked(owner, (folder) async {
      final file = _file(folder, draft.recordId);
      final current = await _summary(owner, file);
      if (current?.version != expectedVersion)
        throw const MomentDraftConflictException();
      validateMomentDraftCapacity(await _summaries(owner, folder), draft);
      final saved = draft.copyWith(version: const Uuid().v4());
      await _write(file, saved);
      return saved;
    });
  }

  @override
  Future<bool> remove(
    String owner,
    String recordId, {
    required String? expectedVersion,
  }) {
    validateMomentDraftIdentity(owner, recordId);
    return _locked(owner, (folder) async {
      final file = _file(folder, recordId);
      final current = await _summary(owner, file);
      if (current == null) return false;
      if (current.version != expectedVersion)
        throw const MomentDraftConflictException();
      await file.delete();
      return true;
    });
  }
}
