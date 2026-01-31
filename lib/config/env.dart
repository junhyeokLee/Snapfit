/// 앱 실행 시점의 환경변수(`--dart-define`)를 읽는 설정 모음.
///
/// 예)
/// - 로컬 백엔드: flutter run --dart-define=BASE_URL=http://localhost:8080
/// - 배포 서버(EC2): flutter run --dart-define=BASE_URL=http://54.253.3.176:8080
class Env {
  /// API Base URL
  ///
  /// `--dart-define=BASE_URL=...` 로 주입 가능.
  /// 기본값은 배포 서버(EC2)로 설정.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://54.253.3.176:8080',
  );
}
