import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/constants/cover_size.dart';
import 'album_source_template.dart';

part 'album.freezed.dart';
part 'album.g.dart';

@freezed
sealed class Album with _$Album {
  const factory Album({
    /// 백엔드의 albumId(int)와 매핑
    /// 생성 API 응답에 albumId가 없을 수도 있어 기본값 허용
    @JsonKey(name: 'albumId') @Default(0) int id,

    /// 커버 레이어 전체 상태(JSON) - 있을 경우 홈에서도 에디터와 동일하게 렌더링
    @Default('') String coverLayersJson,

    /// 서버에서 null 이 와도 안전하게 처리하기 위해 기본값 사용
    @Default('') String ratio,

    /// 앨범 제목
    @Default('') String title,
    String? coverImageUrl,
    String? coverThumbnailUrl,

    /// 운영급: 커버 원본/미리보기 URL (없으면 coverImageUrl을 preview로 간주)
    String? coverOriginalUrl,
    String? coverPreviewUrl,

    /// 커버 테마 (예: classic, nature1) - 서버에서 저장/반환 시 편집 화면에서 복원
    String? coverTheme,
    @Default(0) int totalPages,

    /// 목표 페이지 수 (완성 기준)
    @Default(0) int targetPages,

    /// 사용자 지정 순서 (낮을수록 상단)
    @Default(0) int orders,

    /// 현재 편집 중인 사용자 ID (없으면 null)
    /// 현재 편집 중인 사용자 ID (없으면 null)
    String? lockedBy,

    /// 현재 편집 중인 사용자 고유 ID (없으면 null, 본인 확인용)
    String? lockedById,

    /// 앨범 소유자 ID
    @Default('') String userId,

    /// Current user's access, resolved by the repository; never written to album content.
    @JsonKey(includeToJson: false) String? memberRole,
    @Default('') String createdAt,
    @Default('') String updatedAt,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}

// Album is immutable. Weak keys retain neither old album documents nor an
// unbounded history of edited JSON sources after their albums are collected.
final _physicalCoverSizes = Expando<CoverSize>('album physical cover size');

extension AlbumPhysicalSize on Album {
  /// A local hint only; publication revalidates the active product and license.
  String? get sourceTemplateProductKey {
    try {
      return readAlbumSourceTemplateProductKey(jsonDecode(coverLayersJson));
    } catch (_) {
      return null;
    }
  }

  // Drafts and legacy local fixtures have no server-resolved role yet.
  bool get allowsEditing =>
      memberRole == null || ['OWNER', 'EDITOR'].contains(memberRole);
  bool get allowsManagement => memberRole == null || memberRole == 'OWNER';

  /// Home uses the compact worker result, never a document decode in build.
  CoverSize? get cachedPhysicalCoverSize => _physicalCoverSizes[this];

  CoverSize get estimatedPhysicalCoverSize => resolveAlbumCoverSize(ratio);

  void cachePhysicalCoverSize(CoverSize size) =>
      _physicalCoverSizes[this] = size;

  CoverSize get physicalCoverSize {
    final cached = _physicalCoverSizes[this];
    if (cached != null) return cached;
    Map<String, dynamic>? product;
    try {
      final document = jsonDecode(coverLayersJson);
      if (document is Map && document['printProduct'] is Map) {
        product = Map<String, dynamic>.from(document['printProduct'] as Map);
      }
    } catch (_) {
      // Older albums may contain only a cover URL or an empty document.
    }
    final resolved = resolveAlbumCoverSize(ratio, printProduct: product);
    _physicalCoverSizes[this] = resolved;
    return resolved;
  }
}

/// Resolve only the small ratio/product metadata returned by a worker.
CoverSize resolveAlbumCoverSize(
  String ratio, {
  Map<String, dynamic>? printProduct,
}) {
  final parts = ratio.split(RegExp(r'[:/]'));
  final parsed = parts.length == 2
      ? (double.tryParse(parts[0]) ?? 0) / (double.tryParse(parts[1]) ?? 0)
      : double.tryParse(ratio) ?? 1;
  return resolveCoverSize(ratio: parsed, printProduct: printProduct);
}
