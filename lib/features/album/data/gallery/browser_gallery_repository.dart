import 'package:photo_manager/photo_manager.dart';

import '../../domain/repositories/gallery_repository.dart';
import 'browser_photo_asset.dart';
import 'browser_photo_files.dart';

enum BrowserPhotoImportState { reading, ready, duplicate, failed }

/// Local browser import status. Original bytes are not sent to a server here.
class BrowserPhotoImportProgress {
  const BrowserPhotoImportProgress({
    required this.index,
    required this.total,
    required this.fileName,
    required this.state,
    this.message,
  });

  final int index;
  final int total;
  final String fileName;
  final BrowserPhotoImportState state;
  final String? message;
  bool get isComplete => state != BrowserPhotoImportState.reading;
}

class BrowserPhotoImportResult {
  const BrowserPhotoImportResult(this.added, this.messages);
  final List<BrowserPhotoAsset> added;
  final List<String> messages;
}

class BrowserGalleryRepository implements GalleryRepository {
  BrowserGalleryRepository({required this.currentOwner, this.selectFiles});
  final String? Function() currentOwner;
  final Future<List<BrowserPhotoFile>> Function()? selectFiles;
  String? _owner;
  final List<BrowserPhotoAsset> _photos = [];
  List<BrowserPhotoAsset> get photos {
    _syncOwner();
    return List.unmodifiable(_photos);
  }

  void _syncOwner() {
    final owner = currentOwner();
    if (_owner != owner) {
      _photos.clear();
      _owner = owner;
    }
  }

  Future<BrowserPhotoImportResult> importFiles(
    List<BrowserPhotoFile> files, {
    void Function(BrowserPhotoImportProgress progress)? onProgress,
  }) async {
    _syncOwner();
    final owner = _owner;
    if (owner == null || owner.isEmpty) {
      throw const BrowserPhotoException('로그인한 뒤 사진을 선택해주세요.');
    }
    final added = <BrowserPhotoAsset>[], messages = <String>[];
    if (files.length > browserPhotoMaxCount)
      messages.add('파일은 한 번에 최대 100장까지 가져옵니다. 나머지는 나누어 선택해주세요.');
    var index = 0;
    final total = files.length.clamp(0, browserPhotoMaxCount);
    for (final file in files.take(browserPhotoMaxCount)) {
      final fileIndex = index++;
      void report(BrowserPhotoImportState state, [String? message]) =>
          onProgress?.call(
            BrowserPhotoImportProgress(
              index: fileIndex,
              total: total,
              fileName: file.name,
              state: state,
              message: message,
            ),
          );
      report(BrowserPhotoImportState.reading);
      if (_photos.length >= browserPhotoMaxCount) {
        const message = '한 번에 보관할 사진은 최대 100장이에요. 앨범을 저장한 뒤 선택 목록을 비워주세요.';
        messages.add(message);
        report(BrowserPhotoImportState.failed, message);
        break;
      }
      if (file.size <= 0 || file.size > browserPhotoMaxFileBytes) {
        const message = '사진 한 장은 50MB 이하로 선택해주세요.';
        messages.add('${file.name}: $message');
        report(BrowserPhotoImportState.failed, message);
        continue;
      }
      if (_photos.fold<int>(0, (sum, photo) => sum + photo.byteLength) +
              file.size >
          browserPhotoMaxTotalBytes) {
        const message =
            '선택한 원본 사진은 총 250MB까지 보관할 수 있어요. 앨범을 저장한 뒤 선택 목록을 비워주세요.';
        messages.add(message);
        report(BrowserPhotoImportState.failed, message);
        break;
      }
      try {
        final bytes = await file.readBytes();
        if (currentOwner() != owner)
          throw const BrowserPhotoException('로그인 계정이 변경되어 사진 선택을 중단했어요.');
        if (bytes.length != file.size)
          throw const BrowserPhotoException('파일을 모두 읽지 못했어요. 다시 선택해주세요.');
        final photo = await BrowserPhotoAsset.fromBytes(
          ownerId: owner,
          name: file.name,
          bytes: bytes,
          modifiedAt: file.modifiedAt,
        );
        if (currentOwner() != owner)
          throw const BrowserPhotoException('로그인 계정이 변경되어 사진 선택을 중단했어요.');
        if (_photos.any(
          (existing) => existing.contentSha256 == photo.contentSha256,
        )) {
          report(BrowserPhotoImportState.duplicate, '이미 선택 목록에 있는 사진');
          continue;
        }
        _photos.add(photo);
        added.add(photo);
        report(BrowserPhotoImportState.ready);
      } on BrowserPhotoException catch (error) {
        if (currentOwner() != owner) {
          _syncOwner();
          rethrow;
        }
        messages.add('${file.name}: ${error.message}');
        report(BrowserPhotoImportState.failed, error.message);
      } catch (_) {
        const message = '파일을 읽지 못했어요. 다시 선택해주세요.';
        messages.add('${file.name}: $message');
        report(BrowserPhotoImportState.failed, message);
      }
    }
    return BrowserPhotoImportResult(
      List.unmodifiable(added),
      List.unmodifiable(messages),
    );
  }

  void clearSelectionLibrary() {
    _syncOwner();
    _photos.clear();
  }

  AssetPathEntity get _album => AssetPathEntity(
    id: 'browser-selected-photos',
    name: '선택한 파일',
    isAll: true,
    type: RequestType.image,
  );
  @override
  Future<bool> requestPermission() async {
    _syncOwner();
    if (_owner == null) return false;
    // AI curation also uses this repository. Browsers can only inspect files
    // explicitly chosen by the user, never the computer's entire photo library.
    if (_photos.isEmpty && selectFiles != null) {
      await importFiles(await selectFiles!());
    }
    return currentOwner() == _owner && _owner != null;
  }

  @override
  Future<List<AssetPathEntity>> loadAlbums() async {
    _syncOwner();
    return [_album];
  }

  @override
  Future<AssetPathEntity?> loadAllPhotosAlbum() async {
    _syncOwner();
    return _album;
  }

  @override
  Future<List<AssetEntity>> loadImagesPaged(
    AssetPathEntity album,
    int page,
    int size,
  ) async {
    _syncOwner();
    if (album.id != _album.id || page < 0 || size < 1) return const [];
    return _photos.skip(page * size).take(size).toList(growable: false);
  }
}
