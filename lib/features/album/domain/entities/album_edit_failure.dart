/// Expected editing failures preserve the local document for an explicit retry
/// or discard. They must never trigger a blind write with a newer revision.
sealed class AlbumEditFailure implements Exception {
  const AlbumEditFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class AlbumRevisionConflict extends AlbumEditFailure {
  const AlbumRevisionConflict()
    : super('다른 사람이 먼저 저장했어요. 편집 내용은 유지돼요. 최신 앨범을 확인해 주세요.');
}

class AlbumRevisionRequired extends AlbumEditFailure {
  const AlbumRevisionRequired()
    : super('저장할 앨범의 버전을 확인할 수 없어요. 편집 내용은 유지돼요. 앨범을 다시 불러와 주세요.');
}

class AlbumEditAccessRevoked extends AlbumEditFailure {
  const AlbumEditAccessRevoked()
    : super('앨범의 편집 권한이 변경됐어요. 편집 내용은 이 화면에 유지되지만 앨범에 저장할 수 없어요.');
}

class AlbumEditSessionChanged extends AlbumEditFailure {
  const AlbumEditSessionChanged()
    : super('편집 중인 계정이나 앨범이 변경되어 저장을 멈췄어요. 현재 계정에서 앨범을 다시 열어 주세요.');
}
