import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// sqflite 없이 JSON 파일로 캐시 메타데이터를 저장하는 전용 CacheManager.
/// - Hot restart / 디바이스에서 [MissingPluginException] (getDatabasesPath) 방지
/// - [JsonCacheInfoRepository] + [IOFileSystem] 사용
final snapfitImageCacheManager = CacheManager(
  Config(
    'snapfit_images',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 200,
    repo: JsonCacheInfoRepository(databaseName: 'snapfit_images'),
    fileSystem: IOFileSystem('snapfit_images'),
    fileService: HttpFileService(),
  ),
);
