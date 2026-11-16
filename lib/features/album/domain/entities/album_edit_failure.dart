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

class AlbumCreationRecoveryRequired extends AlbumEditFailure {
  const AlbumCreationRecoveryRequired()
    : super('앨범을 안전하게 이어 만들 준비를 하지 못했어요. 이 화면을 다시 열어 시도해 주세요.');
}

class AlbumCreationRequestConflict extends AlbumEditFailure {
  const AlbumCreationRequestConflict()
    : super('다른 창에서 앨범 만들기 내용이 변경됐어요. 임시 저장한 앨범을 다시 열어 주세요.');
}

class AlbumCreationDeleted extends AlbumEditFailure {
  const AlbumCreationDeleted()
    : super('이 작업으로 만든 앨범은 삭제됐어요. 새 앨범을 만들려면 현재 만들기에서 나간 뒤 새로 시작해 주세요.');
}
