/// 앱 실행 시점의 환경변수(`--dart-define`)를 읽는 설정 모음.
///
/// 예)
/// - Supabase: flutter run --dart-define=SUPABASE_URL=`https://<project>.supabase.co`
class Env {
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
    defaultValue:
        '991239566838-uvukou4dr1ucvkei1efgb38l09s6490g.apps.googleusercontent.com',
  );

  /// 주문 상태 관리자 전환 키(개발/QA용)
  /// - --dart-define=ORDER_ADMIN_KEY=...
  static const String orderAdminKey = String.fromEnvironment(
    'ORDER_ADMIN_KEY',
    defaultValue: '',
  );

  /// Supabase project URL
  /// - --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rrbhxdtriummqpztpjrk.supabase.co',
  );

  /// Supabase anon public key. This is intentionally a public client key;
  /// database access must be protected with RLS policies.
  /// - --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJyYmh4ZHRyaXVtbXFwenRwanJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNDU5MDAsImV4cCI6MjEwMjcyMTkwMH0.uxBcMGAMwAEJZtHA5987jTPePQDY_nNtqMe6W8MejHQ',
  );

  /// Native store subscription product id.
  /// Configure the same id in Google Play Console / App Store Connect.
  /// - --dart-define=IAP_PRO_MONTHLY_PRODUCT_ID=...
  static const String iapProMonthlyProductId = String.fromEnvironment(
    'IAP_PRO_MONTHLY_PRODUCT_ID',
    defaultValue: 'snapfit_pro_monthly',
  );
}
