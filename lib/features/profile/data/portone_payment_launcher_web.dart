import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../domain/portone_payment.dart';

@JS('PortOne')
external _PortOneBrowserSdk? get _browserSdk;

extension type _PortOneBrowserSdk(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestPayment(JSObject request);
}

const _scriptId = 'snapfit-portone-v2-sdk';
Future<void>? _sdkLoad;
bool _requestOpen = false;

Future<void> _loadSdk() {
  if (_browserSdk != null) return Future.value();
  return _sdkLoad ??= _appendSdk().catchError((Object error) {
    _sdkLoad = null;
    throw StateError('portone_browser_sdk_unavailable');
  });
}

Future<void> _appendSdk() async {
  final previous = web.document.getElementById(_scriptId);
  previous?.remove();
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.id = _scriptId;
  script.src = 'https://cdn.portone.io/v2/browser-sdk.js';
  script.async = true;
  final loaded = Completer<void>();
  script.addEventListener(
    'load',
    ((web.Event _) {
      if (!loaded.isCompleted) loaded.complete();
    }).toJS,
  );
  script.addEventListener(
    'error',
    ((web.Event _) {
      if (!loaded.isCompleted)
        loaded.completeError(StateError('sdk_load_failed'));
    }).toJS,
  );
  web.document.head!.appendChild(script);
  try {
    await loaded.future.timeout(const Duration(seconds: 30));
    if (_browserSdk == null) throw StateError('sdk_missing');
  } catch (_) {
    script.remove();
    rethrow;
  }
}

Future<PortOneSdkResult> launchPortOnePayment(
  BuildContext context,
  PortOnePaymentRequest request,
) async {
  if (_requestOpen) {
    return const PortOneSdkResult.failed('sdk_request_in_progress');
  }
  final mobile = RegExp(
    r'Android|iPhone|iPad|iPod',
    caseSensitive: false,
  ).hasMatch(web.window.navigator.userAgent);
  if (mobile && request.redirectUrl == null) {
    return const PortOneSdkResult.failed('payment_redirect_required');
  }
  _requestOpen = true;
  try {
    await _loadSdk();
    final sdk = _browserSdk;
    if (sdk == null) return const PortOneSdkResult.failed('sdk_unavailable');
    final result = await sdk
        .requestPayment(request.toBrowserJson().jsify() as JSObject)
        .toDart;
    return PortOneSdkResult.fromCallback(result?.dartify(), request);
  } catch (_) {
    // The raw SDK error may contain request details; never log or expose it.
    return const PortOneSdkResult.failed('sdk_unavailable');
  } finally {
    _requestOpen = false;
  }
}
