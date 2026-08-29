import '../../data/api/storage_service.dart';

String albumSaveErrorMessage(Object error) {
  if (error is StorageQuotaExceededException) {
    return '저장 공간이 부족해요. 마이페이지에서 사용량을 확인하거나 저장할 사진을 줄여주세요.';
  }

  final raw = error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '')
      .trim();
  final lower = raw.toLowerCase();

  if (raw.contains('로그인이 만료') ||
      raw.contains('Authenticated user is required') ||
      lower.contains('jwt') ||
      lower.contains('auth')) {
    return '로그인이 만료되었어요. 다시 로그인한 뒤 앨범을 저장해주세요.';
  }

  if (lower.contains('failed host lookup') ||
      lower.contains('connection') ||
      lower.contains('network') ||
      lower.contains('timeout') ||
      lower.contains('socket')) {
    return '연결이 불안정해요. 네트워크 상태를 확인한 뒤 다시 저장해주세요.';
  }

  if (raw.contains('이미지 업로드') || lower.contains('upload')) {
    return '일부 사진을 업로드하지 못했어요. 사진 권한과 네트워크 상태를 확인해주세요.';
  }

  if (raw.isEmpty) {
    return '앨범을 저장하지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  return raw;
}
