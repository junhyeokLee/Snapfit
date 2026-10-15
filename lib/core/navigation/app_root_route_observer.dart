import 'package:flutter/widgets.dart';

/// An internal marker; a named route would also change the Flutter web URL.
class AppRootRouteSettings extends RouteSettings {
  const AppRootRouteSettings();
}

/// Order links must wait until Splash has replaced itself with the app root.
/// Otherwise Splash's replacement could remove an already opened order page.
class AppRootRouteObserver extends NavigatorObserver {
  AppRootRouteObserver({required this.onReady});
  final VoidCallback onReady;
  bool _notified = false;

  void _ready(Route<dynamic>? route) {
    if (!_notified && route?.settings is AppRootRouteSettings) {
      _notified = true;
      onReady();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _ready(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _ready(newRoute);
  }
}
