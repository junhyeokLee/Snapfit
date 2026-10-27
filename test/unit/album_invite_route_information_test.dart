import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/web_app_router.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initial direct and hash invitations reach intake before URL cleaning',
    () {
      for (final path in ['/invite/initial', '/#/invite/initial']) {
        final received = <Uri>[];
        final uri = Uri.parse('https://snapfit-c719d.web.app$path');
        final provider = WebAppRouteInformationProvider(
          browserUri: uri,
          onAlbumInvite: received.add,
        );
        expect(received, [uri]);
        expect(provider.value.uri, Uri(path: '/'));
        expect(provider.value.state, isNull);
        provider.dispose();
      }
    },
  );

  test(
    'warm browser invitation preserves the observed page and replaces URL',
    () async {
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        ),
      );
      final received = <Uri>[];
      final provider = WebAppRouteInformationProvider(
        browserUri: Uri.parse('https://snapfit-c719d.web.app/feed'),
        onAlbumInvite: received.add,
      );
      addTearDown(provider.dispose);
      var changes = 0;
      provider.addListener(() => changes++);

      for (final path in ['/invite/next', '/#/invite/next-hash']) {
        await provider.didPushRouteInformation(
          RouteInformation(uri: Uri.parse(path)),
        );
        expect(provider.value.uri, Uri(path: '/feed'));
      }
      expect(received.map((uri) => uri.toString()), [
        'https://snapfit-c719d.web.app/invite/next',
        'https://snapfit-c719d.web.app/#/invite/next-hash',
      ]);
      expect(changes, 0);
      for (final call in calls.where(
        (call) => call.method == 'routeInformationUpdated',
      )) {
        expect(call.arguments, {
          'uri': '/feed',
          'state': null,
          'replace': true,
        });
      }
      expect(
        calls.where((call) => call.method == 'routeInformationUpdated'),
        hasLength(2),
      );
    },
  );

  test(
    'untrusted invitations and ordinary auth or order routes are not captured',
    () async {
      final received = <Uri>[];
      final provider = WebAppRouteInformationProvider(
        browserUri: Uri.parse('https://snapfit-c719d.web.app/feed'),
        onAlbumInvite: received.add,
      );
      addTearDown(provider.dispose);
      var changes = 0;
      provider.addListener(() => changes++);
      for (final source in [
        'https://external.example/invite/foreign',
        '/invite/a?token=a&token=b',
        '/?auth_callback=1&code=oauth-code',
        '/orders/order_123',
        '/#/feed',
      ]) {
        final uri = Uri.parse(source);
        await provider.didPushRouteInformation(RouteInformation(uri: uri));
        expect(provider.value.uri, uri);
      }
      expect(received, isEmpty);
      expect(changes, 5);
    },
  );
}
