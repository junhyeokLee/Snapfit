import 'package:flutter/foundation.dart';

/// 화면/위젯 진입 시 콘솔에 잘 보이게 출력하는 로거
///
/// 디버그 빌드에서만 출력되며, 로그 필터에 `[SnapFit:Screen]` 검색 시 찾기 쉽다.
class ScreenLogger {
  ScreenLogger._();

  static const String _tag = '[SnapFit:Screen]';
  static const String _line = '─────────────────────────────────────────────────────────';

  /// 화면 진입 로그 (스크린 이름 + 설명)
  /// [screenName] 예: 'SplashScreen', 'AlbumCreateFlowScreen'
  /// [description] 예: '앱 초기 로딩', '앨범 생성 Step 1~4 플로우'
  static void enter(String screenName, [String? description]) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint(_line);
    debugPrint('$_tag 진입: $screenName');
    if (description != null && description.isNotEmpty) {
      debugPrint('$_tag   └ $description');
    }
    debugPrint(_line);
    debugPrint('');
  }

  /// 위젯/하위 화면 진입 로그 (스크린 내 주요 위젯용)
  /// [widgetName] 예: 'EditCover', 'HomeAlbumListView'
  /// [description] 예: '커버 편집 캔버스', '앨범 그리드 목록'
  static void widget(String widgetName, [String? description]) {
    if (!kDebugMode) return;
    debugPrint('$_tag [위젯] $widgetName${description != null && description.isNotEmpty ? ' — $description' : ''}');
  }
}
