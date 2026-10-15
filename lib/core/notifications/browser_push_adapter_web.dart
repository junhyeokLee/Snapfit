import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_push_state.dart';

@JS('globalThis.Notification')
external JSObject? get _notificationApi;
@JS('globalThis.PushManager')
external JSObject? get _pushManagerApi;

class BrowserPushAdapter {
  web.ServiceWorkerRegistration? _registration;
  String? _scriptPath;
  Future<void> _writes = Future.value();
  bool _listening = false;
  String? get serviceWorkerScriptPath => _scriptPath;

  BrowserPushEnvironment environment(String vapidKey) {
    try {
      if (!web.window.isSecureContext) {
        return const BrowserPushEnvironment(supported: false, configured: false,
          permission: 'unavailable', message: '브라우저 알림에는 HTTPS 연결이 필요합니다.');
      }
      if (_notificationApi == null || _pushManagerApi == null) {
        return const BrowserPushEnvironment(supported: false, configured: false,
          permission: 'unavailable', message: '이 브라우저에서는 웹 푸시를 사용할 수 없어요. 알림함에서 소식을 확인해주세요.');
      }
      // Accessing an unavailable serviceWorker API throws on some browsers.
      web.window.navigator.serviceWorker;
      final permission = web.Notification.permission;
      var configured = false;
      try {
        final bytes = base64Url.decode(base64Url.normalize(vapidKey.trim()));
        configured = bytes.length == 65 && bytes.first == 4;
      } catch (_) {}
      return BrowserPushEnvironment(supported: true, configured: configured,
        permission: permission,
        message: !configured
          ? '브라우저 알림 연결을 준비 중이에요. 운영자가 Firebase 웹 푸시 공개키를 설정하면 사용할 수 있습니다.'
          : permission == 'denied'
          ? '브라우저에서 알림이 차단되어 있어요. 주소창의 사이트 설정에서 알림을 허용한 뒤 다시 확인해주세요.'
          : '이 브라우저에 알림을 연결하면 웹사이트를 닫은 뒤에도 새 소식을 받을 수 있어요.');
    } catch (_) {
      return const BrowserPushEnvironment(supported: false, configured: false,
        permission: 'unavailable', message: '브라우저 알림을 사용할 수 없어요. 알림함은 계속 이용할 수 있습니다.');
    }
  }

  void listenForClicks(Future<void> Function(Map<String, dynamic>) onTap) {
    if (_listening) return;
    try {
      web.window.navigator.serviceWorker.addEventListener('message', ((web.Event event) {
        final message = (event as web.MessageEvent).data.dartify();
        if (message is! Map || message['type'] != 'SNAPFIT_PUSH_CLICK' ||
            message['data'] is! Map) return;
        // FCM's existing handler checks the current Supabase owner again.
        unawaited(onTap(Map<String, dynamic>.from(message['data'] as Map)));
      }).toJS);
      _listening = true;
    } catch (_) {}
  }

  Future<void> prepare(Map<String, String> options, String vapidKey) async {
    if (!environment(vapidKey).canEnable) return;
    if (_registration?.active != null) return;
    final base = Uri.parse(web.document.baseURI);
    if (base.origin != Uri.base.origin || options['projectId']?.isEmpty != false ||
        options['appId']?.isEmpty != false || options['apiKey']?.isEmpty != false ||
        options['messagingSenderId']?.isEmpty != false) {
      throw StateError('web_push_configuration_unavailable');
    }
    // Only the existing public Firebase web options are present in this URL.
    // A /push/ worker never controls or caches the application document.
    final script = base.resolve('push/firebase-messaging-sw.js').replace(
      queryParameters: {'firebase': base64Url.encode(utf8.encode(jsonEncode(options)))});
    final registration = await web.window.navigator.serviceWorker
        .register(script.toString().toJS).toDart.timeout(const Duration(seconds: 20));
    final worker = registration.installing ?? registration.waiting ?? registration.active;
    if (worker == null) throw StateError('web_push_worker_unavailable');
    if (worker.state != 'activated') {
      final ready = Completer<void>();
      worker.addEventListener('statechange', ((web.Event event) {
        if (worker.state == 'activated' && !ready.isCompleted) ready.complete();
        if (worker.state == 'redundant' && !ready.isCompleted) {
          ready.completeError(StateError('web_push_worker_unavailable'));
        }
      }).toJS);
      // The state can advance between registration and listener attachment.
      if (worker.state == 'activated') ready.complete();
      await ready.future.timeout(const Duration(seconds: 20));
    }
    final metadata = await _send(registration, {'type': 'SNAPFIT_PUSH_METADATA'});
    if (metadata['projectId'] != options['projectId'] ||
        metadata['appId'] != options['appId'] || metadata['version'] != 1) {
      throw StateError('web_push_worker_configuration_mismatch');
    }
    _registration = registration;
    _scriptPath = script.toString();
  }

  // Called directly by the settings button, before any asynchronous setup work.
  Future<bool> requestPermission() => web.Notification.requestPermission()
      .toDart.then((value) => value.toDart == 'granted');

  Future<Map<String, dynamic>> _send(web.ServiceWorkerRegistration registration,
      Map<String, Object?> data) async {
    final worker = registration.active;
    if (worker == null) throw StateError('web_push_worker_unavailable');
    final channel = web.MessageChannel();
    final result = Completer<Map<String, dynamic>>();
    channel.port1.onmessage = ((web.MessageEvent event) {
      final response = event.data.dartify();
      if (response is Map && response['ok'] == true) {
        if (!result.isCompleted) result.complete(Map<String, dynamic>.from(response));
      } else if (!result.isCompleted) {
        result.completeError(StateError('web_push_worker_operation_failed'));
      }
    }).toJS;
    worker.postMessage(data.jsify(), [channel.port2].toJS);
    try {
      return await result.future.timeout(const Duration(seconds: 10));
    } finally {
      channel.port1.close();
      channel.port2.close();
    }
  }

  Future<void> setOwner({required String userId, required int expiresAt,
      required Map<String, bool> preferences}) {
    return _writes = _writes.catchError((_) {}).then((_) async {
      final registration = _registration;
      if (registration == null) throw StateError('web_push_worker_unavailable');
      await _send(registration, {'type': 'SNAPFIT_PUSH_BIND', 'userId': userId,
        'expiresAt': expiresAt, 'preferences': preferences});
    });
  }

  Future<void> clearOwner() {
    return _writes = _writes.catchError((_) {}).then((_) async {
      if (!web.window.isSecureContext || _notificationApi == null || _pushManagerApi == null) return;
      final registrations = await web.window.navigator.serviceWorker
          .getRegistrations().toDart;
      final expected = Uri.parse(web.document.baseURI).resolve('push/firebase-messaging-sw.js');
      for (final registration in registrations.toDart) {
        final script = Uri.tryParse(registration.active?.scriptURL ?? '');
        if (script != null && script.hasScheme &&
            script.origin == expected.origin && script.path == expected.path) {
          await _send(registration, {'type': 'SNAPFIT_PUSH_CLEAR'});
        }
      }
    });
  }

  Future<void> showForeground(Map<String, String> data) async {
    final registration = _registration;
    if (registration == null) return;
    await _send(registration, {'type': 'SNAPFIT_PUSH_FOREGROUND', 'data': data});
  }
}
