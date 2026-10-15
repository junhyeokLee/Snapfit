enum AlbumSavePhase { preparing, uploading, saving, complete }

class AlbumSaveProgress {
  const AlbumSaveProgress(this.phase, {this.completed = 0, this.total = 0});

  final AlbumSavePhase phase;
  final int completed;
  final int total;

  double? get fraction => total > 0 ? completed / total : null;

  String get label => switch (phase) {
    AlbumSavePhase.preparing => '표지를 준비하고 있어요',
    AlbumSavePhase.uploading => '사진 업로드 $completed / $total',
    AlbumSavePhase.saving => '페이지와 편집 내용을 저장하고 있어요',
    AlbumSavePhase.complete => '앨범을 저장했어요',
  };
}
