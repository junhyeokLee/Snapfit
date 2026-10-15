import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/profile/data/customer_print_test_checkout.dart';
import 'package:snap_fit/features/profile/data/print_dev_checkout.dart';

import 'print_dev_checkout_test.dart' as fixture;

class _Repository extends Mock implements PrintDevCheckoutRepository {}

class _Development extends Mock implements PrintDevCheckoutService {}

Map<String, dynamic> customerTestCapability() => {
  'canTest': true,
  'available': true,
  'environment': 'test',
  'isTest': true,
  'productionApproved': false,
  'albumId': 69,
  'reviewedRevision': fixture.devRevision,
  'productId': 'REDP_300_HARD',
  'pageCount': 80,
  'totalAmount': 159900,
  'currency': 'KRW',
  'storeId': PrintDevCheckoutSession.testStoreId,
  'channelKey': PrintDevCheckoutSession.testChannelKey,
};

Map<String, dynamic> customerTestOrder() => {
  ...fixture.devResponse(),
  'albumTitle': 'TEST album',
  'createdAt': '2026-10-15T06:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'capability rejects any LIVE route, price, product or identity drift',
    () {
      expect(
        CustomerPrintTestCapability.fromJson(customerTestCapability())?.albumId,
        69,
      );
      for (final replacement in <Map<String, dynamic>>[
        {'environment': 'production'},
        {'isTest': false},
        {'productionApproved': true},
        {'storeId': 'live-store'},
        {'channelKey': 'live-channel'},
        {'totalAmount': 1},
        {'productId': 'REDP_300_SOFT'},
        {'pageCount': 20},
        {'reviewedRevision': 'unknown'},
      ]) {
        expect(
          () => CustomerPrintTestCapability.fromJson({
            ...customerTestCapability(),
            ...replacement,
          }),
          throwsFormatException,
        );
      }
      expect(
        CustomerPrintTestCapability.fromJson({
          'canTest': false,
          'environment': 'disabled',
        }),
        isNull,
      );
    },
  );

  test(
    'customer TEST recovery preserves previous admin and other owners',
    () async {
      SharedPreferences.setMockInitialValues({});
      final previous = PrintDevCheckoutStore();
      final customer = CustomerPrintTestCheckoutStore();
      await previous.write('owner-a', {'runId': 'previous-admin-run'});
      await customer.write('owner-a', {
        'runId': 'customer-run',
        'sdkStarted': true,
      });
      expect((await previous.read('owner-a'))?['runId'], 'previous-admin-run');
      expect((await customer.read('owner-a'))?['runId'], 'customer-run');
      expect((await customer.read('owner-a'))?['sdkStarted'], isTrue);
      expect(await customer.read('owner-b'), isNull);
    },
  );

  test(
    'history and detail only read server TEST records and match identities',
    () async {
      final repo = _Repository(), development = _Development();
      when(() => development.repository).thenReturn(repo);
      when(() => repo.invoke('history', any())).thenAnswer(
        (_) async => {
          'environment': 'test',
          'isTest': true,
          'productionApproved': false,
          'orders': [customerTestOrder()],
        },
      );
      when(() => repo.invoke('detail', any())).thenAnswer(
        (_) async => {
          ...customerTestOrder(),
          'recipient': {'name': 'TEST', 'phone': '01000000000'},
        },
      );
      final service = CustomerPrintTestCheckoutService(development);
      expect((await service.history()).single.session.runId, fixture.devRun);
      expect((await service.detail(fixture.devRun)).recipient['name'], 'TEST');
      verify(() => repo.invoke('history', const {})).called(1);
      verify(() => repo.invoke('detail', {'runId': fixture.devRun})).called(1);
      verifyNoMoreInteractions(repo);
      when(() => repo.invoke('detail', any())).thenAnswer(
        (_) async => {
          ...customerTestOrder(),
          'runId': fixture.devRequest,
          'orderId': 'ordp_${fixture.devRequest}',
        },
      );
      await expectLater(service.detail(fixture.devRun), throwsFormatException);
    },
  );

  test(
    'history never accepts production records or delivery details in a list',
    () async {
      final repo = _Repository(), development = _Development();
      when(() => development.repository).thenReturn(repo);
      final service = CustomerPrintTestCheckoutService(development);
      for (final response in [
        {
          'environment': 'production',
          'isTest': false,
          'productionApproved': true,
          'orders': [customerTestOrder()],
        },
        {
          'environment': 'test',
          'isTest': true,
          'productionApproved': false,
          'orders': [
            {...customerTestOrder(), 'recipient': <String, dynamic>{}},
          ],
        },
      ]) {
        when(
          () => repo.invoke('history', any()),
        ).thenAnswer((_) async => response);
        await expectLater(service.history(), throwsFormatException);
      }
    },
  );
}
