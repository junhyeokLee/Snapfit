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
    defaultValue: 'http://54.253.3.176', // Nginx Reverse Proxy (Port 80)
  );

  /// Kakao Native App Key
  /// - --dart-define=KAKAO_NATIVE_APP_KEY=...
  static const String kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '34ecdf62d2b450c00c1d525d0cffa4df',
  );

  /// Google Web Client ID (serverClientId)
  /// - --dart-define=GOOGLE_WEB_CLIENT_ID=...
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '991239566838-uvukou4dr1ucvkei1efgb38l09s6490g.apps.googleusercontent.com',
  );
}
