import 'layer.dart';

const Object _unsetBackgroundColor = Object();

class AlbumPage {
  final String id; // page 고유 ID (로컬 편집용)
  final List<LayerModel> layers; // 이미지/텍스트 레이어들
  final int pageIndex; // 페이지 순서
  final bool isCover; // 표지인지 여부
  final int? backgroundColor; // 배경색 (ARGB)

  AlbumPage({
    required this.id,
    required this.layers,
    required this.pageIndex,
    this.isCover = false,
    this.backgroundColor,
  });

  AlbumPage copyWith({
    String? id,
    List<LayerModel>? layers,
    int? pageIndex,
    bool? isCover,
    Object? backgroundColor = _unsetBackgroundColor,
  }) {
    return AlbumPage(
      id: id ?? this.id,
      layers: layers ?? this.layers,
      pageIndex: pageIndex ?? this.pageIndex,
      isCover: isCover ?? this.isCover,
      backgroundColor: identical(backgroundColor, _unsetBackgroundColor)
          ? this.backgroundColor
          : backgroundColor as int?,
    );
  }
}
