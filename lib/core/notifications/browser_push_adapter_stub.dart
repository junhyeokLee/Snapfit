import 'browser_push_state.dart';

/// Native notifications continue through the existing Firebase/native path.
class BrowserPushAdapter {
  BrowserPushEnvironment environment(String vapidKey) =>
      const BrowserPushEnvironment(supported: false, configured: false,
        permission: 'unavailable', message: '브라우저에서 사용할 수 있는 기능입니다.');
  String? get serviceWorkerScriptPath => null;
  void listenForClicks(Future<void> Function(Map<String, dynamic>) onTap) {}
  Future<void> prepare(Map<String, String> options, String vapidKey) async {}
  Future<bool> requestPermission() async => false;
  Future<void> setOwner({required String userId, required int expiresAt,
    required Map<String, bool> preferences}) async {}
  Future<void> clearOwner() async {}
  Future<void> showForeground(Map<String, String> data) async {}
}
