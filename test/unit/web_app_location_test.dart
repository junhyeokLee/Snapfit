import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/navigation/web_app_router.dart';

void main() {
  const run = '85e8ce97-1d30-41ee-892b-4c43ee5546f3';
  final cases = <String, WebAppLocation>{
    '/': WebAppLocation.home,
    '/create': WebAppLocation.create,
    '/albums/69': const WebAppLocation(WebAppPage.album, '69'),
    '/albums/69/edit': const WebAppLocation(WebAppPage.editor, '69'),
    '/albums/69/print': const WebAppLocation(WebAppPage.print, '69'),
    '/orders': WebAppLocation.orders,
    '/orders/order_ABC-123': const WebAppLocation(
      WebAppPage.order,
      'order_ABC-123',
    ),
    '/test-orders/$run': const WebAppLocation(WebAppPage.testOrder, run),
  };

  for (final entry in cases.entries) {
    test(
      'public location ${entry.key} round trips without hidden state',
      () async {
        final location = WebAppLocation.parse(Uri.parse(entry.key));
        expect(location, entry.value);
        expect(location.uri.toString(), entry.key);
        const parser = WebAppRouteParser();
        final parsed = await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse(entry.key)),
        );
        expect(parsed, entry.value);
        expect(
          parser.restoreRouteInformation(parsed).uri.toString(),
          entry.key,
        );
      },
    );
  }

  test('hash based browser routes produce the same clean public location', () {
    final uri = Uri.parse(
      'https://snapfit.example/#/albums/69/edit?phone=01000000000&token=private',
    );
    final location = WebAppLocation.parse(uri);
    expect(location, const WebAppLocation(WebAppPage.editor, '69'));
    expect(location.uri.toString(), '/albums/69/edit');
    expect(location.uri.hasQuery, isFalse);
    expect(location.uri.hasFragment, isFalse);
    expect(location.uri.hasAuthority, isFalse);
  });

  test('malformed album IDs and unsupported paths return home', () {
    for (final value in [
      '/albums/0',
      '/albums/-1',
      '/albums/nope',
      '/albums/1.5',
      '/albums/9007199254740992',
      '/albums/99999999999999999999999999',
      '/albums/69/delete',
      '/albums/69/edit/more',
      '/unknown',
      '/orders/a%2Fb',
      '/orders/a%40example.com',
      '/orders/${'a' * 201}',
      '/test-orders/not-a-uuid',
      '/test-orders/85E8CE97-1D30-41EE-892B-4C43EE5546F3',
      '/test-orders/$run/more',
    ]) {
      expect(
        WebAppLocation.parse(Uri.parse(value)),
        WebAppLocation.home,
        reason: value,
      );
    }
  });

  test('URI normalizes dot segments before the location parser sees them', () {
    expect(
      WebAppLocation.parse(Uri.parse('/orders/../albums/69')),
      const WebAppLocation(WebAppPage.album, '69'),
    );
  });

  test(
    'numeric IDs normalize and stay inside JavaScript safe integer range',
    () {
      expect(
        WebAppLocation.parse(Uri.parse('/albums/00069')).uri.toString(),
        '/albums/69',
      );
      expect(
        WebAppLocation.parse(Uri.parse('/albums/9007199254740991')).id,
        '9007199254740991',
      );
    },
  );

  test(
    'external origin query PII and payment callback data never become restored URL state',
    () async {
      const parser = WebAppRouteParser();
      final source = Uri.parse(
        'https://outside.example/albums/69/print?email=person%40example.com&address=private&paymentId=untrusted&txId=untrusted#token=private',
      );
      final parsed = await parser.parseRouteInformation(
        RouteInformation(
          uri: source,
          state: {'paid': true, 'recipient': 'private'},
        ),
      );
      final restored = parser.restoreRouteInformation(parsed);
      expect(restored.uri.toString(), '/albums/69/print');
      expect(restored.state, isNull);
      expect(restored.uri.queryParameters, isEmpty);
      expect(restored.uri.fragment, isEmpty);
      expect(restored.uri.host, isEmpty);
    },
  );

  test(
    'payment return parameters never create a paid order navigation target',
    () {
      final unknownReturn = WebAppLocation.parse(
        Uri.parse(
          '/payment-return?paymentId=untrusted&status=PAID&success=true',
        ),
      );
      expect(unknownReturn, WebAppLocation.home);
      final orderWithCallback = WebAppLocation.parse(
        Uri.parse('/orders/order-123?status=PAID&amount=1'),
      );
      expect(
        orderWithCallback,
        const WebAppLocation(WebAppPage.order, 'order-123'),
      );
      expect(orderWithCallback.uri.toString(), '/orders/order-123');
    },
  );

  test('location identity includes both page and object ID', () {
    const album = WebAppLocation(WebAppPage.album, '69');
    const duplicate = WebAppLocation(WebAppPage.album, '69');
    expect(album, duplicate);
    expect(album.hashCode, duplicate.hashCode);
    expect(album, isNot(const WebAppLocation(WebAppPage.editor, '69')));
    expect(album, isNot(const WebAppLocation(WebAppPage.album, '70')));
    expect(const WebAppRouteSettings(album).location, album);
  });
}
