import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../domain/web_point_topup.dart';

@JS('PortOne')
external _PointPortOneSdk? get _sdk;
extension type _PointPortOneSdk(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestPayment(JSObject request);
}
Future<void>? _loading;

class _SdkWindow {
  _SdkWindow(this.paymentId, this.ownerId);
  final String paymentId, ownerId;
  bool terminalConfirmed = false;
}

_SdkWindow? _open;
bool get hasUnresolvedWindow => _open != null;

/// A server result retires the panel operation, not an unresolved physical SDK.
/// PortOne can run global driver cleanup when that old Promise eventually ends.
void confirmTerminal(WebPointTopup row) {
  final open = _open;
  if (open == null ||
      open.paymentId != row.paymentId ||
      open.ownerId != row.ownerId ||
      row.pending ||
      !const {
        'CREDITED',
        'VERIFIED_TEST',
        'REFUNDED',
        'VOIDED',
        'FAILED',
      }.contains(row.status))
    return;
  open.terminalConfirmed = true;
}

void ensureSupported() {
  if (RegExp(
    r'Android|iPhone|iPad|iPod',
    caseSensitive: false,
  ).hasMatch(web.window.navigator.userAgent)) {
    throw const WebPointTopupException('web_point_desktop_required');
  }
  if (_open != null) {
    throw WebPointTopupException(
      _open!.terminalConfirmed
          ? 'web_point_previous_window_unresolved'
          : 'web_point_window_unresolved',
    );
  }
}

Future<void> _load() async {
  if (_sdk != null) return;
  final script = web.HTMLScriptElement()
    ..src = 'https://cdn.portone.io/v2/browser-sdk.js'
    ..async = true;
  final ready = Completer<void>();
  script.addEventListener(
    'load',
    ((web.Event _) {
      if (!ready.isCompleted) ready.complete();
    }).toJS,
  );
  script.addEventListener(
    'error',
    ((web.Event _) {
      if (!ready.isCompleted)
        ready.completeError(
          const WebPointTopupException('web_point_sdk_unavailable'),
        );
    }).toJS,
  );
  web.document.head?.appendChild(script);
  try {
    await ready.future.timeout(const Duration(seconds: 30));
    if (_sdk == null)
      throw const WebPointTopupException('web_point_sdk_unavailable');
  } catch (_) {
    script.remove();
    rethrow;
  }
}

Future<void> prepareSdk() async {
  ensureSupported();
  try {
    await (_loading ??= _load());
  } catch (_) {
    _loading = null;
    rethrow;
  }
}

Future<void> launch(WebPointSdkRequest request) async {
  if (!request.topup.isTest && !webPointTopupLiveCheckoutReleased)
    throw const WebPointTopupException('web_point_checkout_closed');
  // This release deliberately does not add a half-working redirect checkout.
  // Mobile/native point purchases continue to use the existing store IAP.
  ensureSupported();
  // Load without claiming a window, then recheck after the asynchronous boundary
  // so concurrent callers cannot both enter the provider SDK.
  await prepareSdk();
  ensureSupported();
  final operation = _SdkWindow(request.topup.paymentId, request.topup.ownerId);
  _open = operation;
  try {
    final sdk = _sdk;
    if (sdk == null)
      throw const WebPointTopupException('web_point_sdk_unavailable');
    // Do not interpret success/cancel/error payload as a payment result.
    await sdk
        .requestPayment(request.toBrowserJson().jsify() as JSObject)
        .toDart;
  } finally {
    if (identical(_open, operation)) _open = null;
  }
}
