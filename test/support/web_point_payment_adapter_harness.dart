// Compiled to JavaScript by the Node regression test. This imports the actual
// browser adapter, while replacing only PortOne's external network/SDK Promise.
import 'dart:async';
import 'dart:js_interop';

import 'package:snap_fit/features/billing/data/web_point_payment_launcher_web.dart'
    as adapter;
import 'package:snap_fit/features/billing/domain/web_point_topup.dart';

@JS('pointAdapterFixture.count')
external JSNumber get _requestCount;
@JS('pointAdapterFixture.lastPayment')
external JSString get _lastPayment;
@JS('pointAdapterFixture.settle')
external void _settle(JSString paymentId, JSBoolean error);

const _owner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '22222222-2222-4222-8222-222222222222';
String _id(int number) =>
    'SFPTT_aaaaaaaa-aaaa-4aaa-8aaa-${number.toString().padLeft(12, '0')}';
Map<String, dynamic> _row(
  int number, {
  bool terminal = false,
  String owner = _owner,
}) => {
  'paymentId': _id(number),
  'ownerId': owner,
  'productId': 'snapfit_points_2500',
  'title': '2,500P',
  'points': 2500,
  'totalAmount': 2200,
  'currency': 'KRW',
  'status': terminal ? 'VERIFIED_TEST' : 'PENDING',
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'sdkStartedAt': DateTime.now().toUtc().toIso8601String(),
  'verifiedAt': terminal ? DateTime.now().toUtc().toIso8601String() : null,
  'refundedAt': null,
  'serverVerified': terminal,
  'environment': 'test',
  'isTest': true,
  'productionApproved': false,
  'realPointsGranted': 0,
  'storeId': webPointTestStoreId,
  'channelKey': webPointTestChannelKey,
  'canLaunch': false,
  'sdkLaunchAuthorized': true,
};
WebPointSdkRequest _request(int number) =>
    WebPointSdkRequest.fromAuthorized(_row(number));
void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 1));
String _blockedCode() {
  try {
    adapter.ensureSupported();
  } on WebPointTopupException catch (error) {
    return error.code;
  }
  throw StateError('Unresolved physical SDK window was not fenced');
}

Future<String> _outcome(WebPointSdkRequest request) async {
  try {
    await adapter.launch(request);
    return 'returned';
  } on WebPointTopupException catch (error) {
    return error.code;
  } catch (_) {
    return 'sdk-error';
  }
}

Future<void> main() async {
  adapter.ensureSupported();
  final old = _outcome(_request(1));
  await _tick();
  _expect(_requestCount.toDartInt == 1, 'The first SDK request did not start');
  _expect(adapter.hasUnresolvedWindow, 'Physical SDK window not tracked');
  _expect(
    _blockedCode() == 'web_point_window_unresolved',
    'Pending window lost its fence',
  );
  adapter.confirmTerminal(WebPointTopup.fromJson(_row(2, terminal: true)));
  adapter.confirmTerminal(
    WebPointTopup.fromJson(_row(1, terminal: true, owner: _otherOwner)),
  );
  adapter.confirmTerminal(WebPointTopup.fromJson(_row(1)));
  _expect(
    _blockedCode() == 'web_point_window_unresolved',
    'Wrong invoice, owner or pending state retired the active window',
  );
  adapter.confirmTerminal(WebPointTopup.fromJson(_row(1, terminal: true)));
  _expect(
    _blockedCode() == 'web_point_previous_window_unresolved',
    'Confirmed invoice needs explicit physical-window guidance',
  );
  var newPrepares = 0;
  try {
    // The panel performs this exact adapter preflight before prepare/start.
    adapter.ensureSupported();
    newPrepares++;
  } on WebPointTopupException {
    /* Keep the existing invoice and SDK. */
  }
  _expect(
    newPrepares == 0,
    'A new invoice was prepared while the old SDK was hung',
  );
  _expect(
    await _outcome(_request(2)) == 'web_point_previous_window_unresolved',
    'A second physical SDK entered',
  );
  _expect(
    _requestCount.toDartInt == 1,
    'SDK was called again before physical cleanup',
  );
  _settle(_id(1).toJS, true.toJS);
  _expect(
    await old == 'sdk-error',
    'Late SDK rejection was not observed safely',
  );
  _expect(
    !adapter.hasUnresolvedWindow,
    'Physical settlement failed to release its own window',
  );
  adapter.ensureSupported();

  final current = _outcome(_request(2));
  await _tick();
  adapter.confirmTerminal(WebPointTopup.fromJson(_row(1, terminal: true)));
  _expect(
    _blockedCode() == 'web_point_window_unresolved',
    'An old terminal invoice changed a new window',
  );
  _expect(
    _requestCount.toDartInt == 2,
    'New SDK did not start after old cleanup',
  );
  _settle(_id(2).toJS, false.toJS);
  _expect(await current == 'returned', 'Second SDK did not finish');

  // Even callers that race while SDK loading share one physical request.
  final raceA = _outcome(_request(3)), raceB = _outcome(_request(4));
  await _tick();
  _expect(
    _requestCount.toDartInt == 3,
    'Concurrent callers opened multiple SDK windows',
  );
  _settle(_lastPayment, false.toJS);
  final outcomes = await Future.wait([raceA, raceB]);
  _expect(
    outcomes.where((item) => item == 'returned').length == 1,
    'One racing operation must own the window',
  );
  _expect(
    outcomes.where((item) => item == 'web_point_window_unresolved').length == 1,
    'The other racing operation must remain blocked',
  );
  _expect(!adapter.hasUnresolvedWindow, 'Final window guard did not release');
  // ignore: avoid_print
  print(
    'web-point-adapter: verified real JS guard, no-new-prepare, exact invoice/owner, late error and concurrent launch',
  );
}
