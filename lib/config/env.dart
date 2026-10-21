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
  /// Supabase Google signInWithIdToken requires this to match the Google
  /// OAuth web client configured in Supabase Auth > Providers > Google.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '991239566838-uvukou4dr1ucvkei1efgb38l09s6490g.apps.googleusercontent.com',
  );

  /// Google iOS client ID. Android normally reads its client ID from
  /// google-services.json, but iOS requires an explicit clientId or
  /// GoogleService-Info.plist URL scheme configuration.
  /// - --dart-define=GOOGLE_IOS_CLIENT_ID=...
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
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

  /// Supabase Auth email confirmation/recovery redirect URL.
  /// Register this URL in Supabase Auth > URL Configuration > Redirect URLs
  /// and native Android/iOS deep-link settings.
  /// - --dart-define=AUTH_REDIRECT_URL=snapfit://auth/callback
  static const String authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'snapfit://auth/callback',
  );

  /// Browser OAuth/email links return to the current app origin's root.
  /// Register each exact /?auth_callback=1 URL in Supabase Auth URL settings.
  /// Empty uses the current origin; cross-origin overrides are rejected.
  static const String authWebRedirectUrl = String.fromEnvironment(
    'AUTH_WEB_REDIRECT_URL',
    defaultValue: '',
  );

  /// Public Firebase Web Push certificate key. Permission is requested only
  /// from the user's notification-settings action, never at app startup.
  /// This public key belongs to the same Firebase project as firebase_options.
  static const String webPushVapidKey = String.fromEnvironment(
    'WEB_PUSH_VAPID_KEY',
    defaultValue:
        'BHhzjA6l5X3vUv_6GY2o7QagvNvrLLSXrBFfNME9RGSF4hHkdx4TARjK-SWqMyxiWaFB_Izn1e1ifW_r1ZP6AOA',
  );

  /// Preparation only: a matching server flag and verified admin role are also
  /// required for TEST top-ups. This never enables real web point payments.
  static const bool webPointTopupTestEnabled = bool.fromEnvironment(
    'WEB_POINT_TOPUP_TEST_ENABLED',
    defaultValue: false,
  );

  /// Enables server-backed AI album draft generation through Supabase Edge
  /// Function. Keep false until server prompts/model quality and privacy copy
  /// are production-ready.
  /// - --dart-define=USE_SERVER_AI_ALBUM_DRAFT=true
  static const bool useServerAiAlbumDraft = bool.fromEnvironment(
    'USE_SERVER_AI_ALBUM_DRAFT',
    defaultValue: false,
  );

  /// AI album draft base point cost (20 pages). Actual cost scales with page
  /// count: 300 + pageCount * 10 (500P for 20p ~ 1100P for 80p).
  /// - --dart-define=AI_ALBUM_DRAFT_POINT_COST=500
  static const int aiAlbumDraftPointCost = int.fromEnvironment(
    'AI_ALBUM_DRAFT_POINT_COST',
    defaultValue: 500,
  );

  /// Native store consumable point product ids. Configure matching ids in
  /// Google Play Console / App Store Connect.
  /// - --dart-define=IAP_POINT_PRODUCT_IDS=snapfit_points_2500,snapfit_points_8000,snapfit_points_18000
  static const String iapPointProductIdsCsv = String.fromEnvironment(
    'IAP_POINT_PRODUCT_IDS',
    defaultValue:
        'snapfit_points_2500,snapfit_points_8000,snapfit_points_18000',
  );

  static List<String> get iapPointProductIds => iapPointProductIdsCsv
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  /// Enables advanced server photo understanding for AI album drafts. This may
  /// send small preview thumbnails to the server, so keep disabled until the
  /// explicit consent copy, retention policy, and server pipeline are ready.
  /// - --dart-define=USE_ADVANCED_SERVER_AI_ALBUM_ANALYSIS=true
  static const bool useAdvancedServerAiAlbumAnalysis = bool.fromEnvironment(
    'USE_ADVANCED_SERVER_AI_ALBUM_ANALYSIS',
    defaultValue: false,
  );
}
