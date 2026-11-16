import '../../../../core/constants/cover_size.dart';
import 'layer.dart';

/// 사진 선택 화면만 수정하는 작업본. 원본 페이지 목록과는 공유하지 않는다.
class AlbumPhotoFillDraft {
  AlbumPhotoFillDraft({
    required List<List<LayerModel>> pages,
    required this.cover,
    required this.pageIndex,
    required this.ownerId,
    required this.sessionIdentity,
    required this.albumId,
  }) : pages = [for (final page in pages) List<LayerModel>.of(page)];

  final List<List<LayerModel>> pages;
  final CoverSize cover;
  final int pageIndex;
  final String ownerId;
  final Object sessionIdentity;
  final int? albumId;
}
