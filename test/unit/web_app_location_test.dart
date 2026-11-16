import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/navigation/web_app_router.dart';

void main() {
  test(
    'monthly public routes preserve owner and calendar month without granting private access',
    () {
      final location = WebAppLocation.socialMomentMonth(
        'author',
        DateTime.utc(2026, 10, 28),
      );
      expect(location.uri.path, '/users/author/months/2026-10');
      expect(location.momentMonthUserId, 'author');
      expect(location.momentMonthDate, DateTime.utc(2026, 10));
      expect(location.isPublic, isTrue);
      for (final path in [
        '/users/author/months/2026-13',
        '/users/author/months/2026-00',
        '/users/author/months/1899-12',
        '/users/author/months/2026-10/records',
        '/users/author/months/2026-10-01',
      ]) {
        expect(WebAppLocation.parse(Uri.parse(path)), WebAppLocation.home);
      }
    },
  );
  const run = '85e8ce97-1d30-41ee-892b-4c43ee5546f3';
  final cases = <String, WebAppLocation>{
    '/': WebAppLocation.home,
    '/login': WebAppLocation.login,
    '/designs': WebAppLocation.designs,
    '/designs/materials': WebAppLocation.materials,
    '/designs/templates/-9403': const WebAppLocation(
      WebAppPage.template,
      '-9403',
    ),
    '/albums': WebAppLocation.albums,
    '/feed': WebAppLocation.feed,
    '/account/safety': WebAppLocation.safety,
    '/account/safety/reports': WebAppLocation.safetyReports,
    '/users/user_123/months/2026-10': const WebAppLocation(
      WebAppPage.socialMomentMonth,
      'user_123/2026-10',
    ),
    '/works/work_123': const WebAppLocation(WebAppPage.socialWork, 'work_123'),
    '/users/user_123': const WebAppLocation(
      WebAppPage.socialProfile,
      'user_123',
    ),
    '/me': WebAppLocation.myProfile,
    '/attendance': WebAppLocation.attendance,
    '/moments': WebAppLocation.moments,
    '/friends': WebAppLocation.referral,
    '/friends/ABCD2345XY': WebAppLocation(WebAppPage.referral, 'ABCD2345XY'),
    '/me/works': WebAppLocation.socialManage,
    '/publish': WebAppLocation.socialPublish,
    '/publish/69': const WebAppLocation(WebAppPage.socialPublish, '69'),
    '/create': WebAppLocation.create,
    '/albums/69': const WebAppLocation(WebAppPage.album, '69'),
    '/albums/69/edit': const WebAppLocation(WebAppPage.editor, '69'),
    '/albums/69/print': const WebAppLocation(WebAppPage.print, '69'),
    '/orders': WebAppLocation.orders,
    '/print-products': WebAppLocation.printProducts,
    '/policies/terms': const WebAppLocation(WebAppPage.policy, 'terms'),
    '/policies/refund': const WebAppLocation(WebAppPage.policy, 'refund'),
    '/policies/privacy': const WebAppLocation(WebAppPage.policy, 'privacy'),
    '/policies/shipping': const WebAppLocation(WebAppPage.policy, 'shipping'),
    '/policies/seller': const WebAppLocation(WebAppPage.policy, 'seller'),
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

  test(
    'friend query and lowercase codes canonicalize to the public code path',
    () {
      for (final value in [
        '/friends?code=abcd2345xy',
        '/friends/abcd2345xy',
        'https://snapfit-c719d.web.app/#/friends?code=abcd2345xy',
      ]) {
        final location = WebAppLocation.parse(Uri.parse(value));
        expect(
          location,
          const WebAppLocation(WebAppPage.referral, 'ABCD2345XY'),
        );
        expect(location.uri.toString(), '/friends/ABCD2345XY');
      }
    },
  );

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

  test(
    'direct and hash material links browse without account verification',
    () {
      for (final address in [
        'https://snapfit-c719d.web.app/designs/materials',
        'https://snapfit-c719d.web.app/#/designs/materials',
      ]) {
        final location = WebAppLocation.parse(Uri.parse(address));
        expect(location, WebAppLocation.materials);
        expect(location.uri.toString(), '/designs/materials');
        expect(location.isPublic, isTrue);
      }
      expect(WebAppLocation.library.isPublic, isFalse);
      expect(WebAppLocation.create.isPublic, isFalse);
    },
  );

  test('invitation capabilities stay outside normal page locations', () {
    for (final value in [
      'https://snapfit-c719d.web.app/invite/private-capability',
      'https://snapfit-c719d.web.app/#/invite/private-capability',
      '/invite/private-capability',
    ]) {
      final location = WebAppLocation.parse(Uri.parse(value));
      expect(location, WebAppLocation.home);
      expect(location.uri.toString(), '/');
      expect(location.uri.toString(), isNot(contains('private-capability')));
    }
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
      '/works/a%2Fb',
      '/users/person%40example.com',
      '/works/${'a' * 201}',
      '/feed/private',
      '/me/works/extra',
      '/attendance/extra',
      '/friends/INVALID',
      '/friends/ABCD2345XY/extra',
      '/friends?code=ABCD2345XY&code=ABCD2345XY',
      '/friends/ABCD2345XY?code=ABCD2345XY',
      '/publish/0',
      '/publish/-1',
      '/publish/9007199254740992',
      '/publish/69/extra',
      '/unknown',
      '/policies/unknown',
      '/policies/terms/private',
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

  test('discovery is public while customer documents remain authenticated', () {
    expect(WebAppLocation.printProducts.isPublic, isTrue);
    for (final slug in WebAppLocation.policySlugs) {
      expect(WebAppLocation(WebAppPage.policy, slug).isPublic, isTrue);
    }
    expect(
      const WebAppLocation(WebAppPage.policy, 'unknown').isPublic,
      isFalse,
    );
    for (final page in WebAppPage.values.where(
      (page) => ![
        WebAppPage.home,
        WebAppPage.login,
        WebAppPage.feed,
        WebAppPage.socialWork,
        WebAppPage.socialProfile,
        WebAppPage.socialMomentMonth,
        WebAppPage.referral,
        WebAppPage.designs,
        WebAppPage.materials,
        WebAppPage.template,
        WebAppPage.printProducts,
        WebAppPage.policy,
      ].contains(page),
    )) {
      expect(WebAppLocation(page, '69').isPublic, isFalse);
    }
    expect(WebAppLocation.designs.isPublic, isTrue);
    expect(WebAppLocation.materials.isPublic, isTrue);
    expect(WebAppLocation.feed.isPublic, isTrue);
    expect(
      const WebAppLocation(WebAppPage.socialWork, 'work_123').isPublic,
      isTrue,
    );
    expect(
      const WebAppLocation(WebAppPage.socialProfile, 'user_123').isPublic,
      isTrue,
    );
    expect(WebAppLocation.myProfile.isPublic, isFalse);
    expect(WebAppLocation.safety.isPublic, isFalse);
    expect(WebAppLocation.safetyReports.isPublic, isFalse);
    expect(WebAppLocation.referral.isPublic, isTrue);
    expect(WebAppLocation.socialPublish.isPublic, isFalse);
    expect(WebAppLocation.socialManage.isPublic, isFalse);
    expect(WebAppLocation.login.isPublic, isTrue);
    expect(const WebAppLocation(WebAppPage.template, '-9403').isPublic, isTrue);
  });
}
