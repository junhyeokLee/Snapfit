import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_root_route_observer.dart';
import 'web_app_location.dart';

class WebAppRouteParser extends RouteInformationParser<WebAppLocation> {
  const WebAppRouteParser();
  @override
  Future<WebAppLocation> parseRouteInformation(
    RouteInformation routeInformation,
  ) => SynchronousFuture(WebAppLocation.parse(routeInformation.uri));
  @override
  RouteInformation restoreRouteInformation(WebAppLocation configuration) =>
      RouteInformation(uri: configuration.uri);
}

/// Keeps the existing imperative editor/dialog navigation under Flutter's
/// Router, which handles browser history, direct links and forward navigation.
class WebAppRouter extends RouterDelegate<WebAppLocation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<WebAppLocation> {
  WebAppRouter({
    required this.navigatorKey,
    required this.observers,
    required this.routeBuilder,
    required this.onLocationRequested,
  }) {
    _observer = _WebLocationObserver(_observed);
  }

  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final List<NavigatorObserver> observers;
  final RouteFactory routeBuilder;
  final ValueChanged<WebAppLocation> onLocationRequested;
  late final _WebLocationObserver _observer;
  WebAppLocation _location = WebAppLocation.home;
  bool _requestPending = true;
  WebAppLocation get observedLocation => _observer.location;
  bool isDisplayingLocation(WebAppLocation location) => _observer.isDisplaying(location);

  /// Internal menu requests publish one final location, after guarded pops and
  /// any asynchronous preparation, rather than publishing intermediate roots.
  void requestLocation(WebAppLocation location) {
    _requestPending = true;
    onLocationRequested(location);
  }

  @override
  WebAppLocation get currentConfiguration => _location;

  @override
  Future<void> setNewRoutePath(WebAppLocation configuration) async {
    _requestPending = true;
    _location = configuration;
    onLocationRequested(configuration);
  }

  void finishInitialNavigation() {
    _requestPending = false;
    _observed(_observer.location);
  }

  void _observed(WebAppLocation next) {
    if (_requestPending) return;
    if (next == _location) return;
    _location = next;
    notifyListeners();
  }

  void restoreObservedLocation() {
    _requestPending = false;
    _location = _observer.location;
    notifyListeners();
  }

  /// Respect the editor's PopScope/save prompt; never discard work to satisfy
  /// a browser URL. A blocked pop leaves the original location active.
  Future<bool> returnToRoot() async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    while (navigator.canPop()) {
      final previous = _observer.top;
      await navigator.maybePop();
      // A blocked PopScope may push its save dialog synchronously. The top
      // route then changes even though the editor itself has not been popped.
      if (_observer.contains(previous)) {
        restoreObservedLocation();
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    initialRoute: '/',
    onGenerateRoute: routeBuilder,
    observers: [...observers, _observer],
    reportsRouteUpdateToEngine: false,
  );
}

class _WebLocationObserver extends NavigatorObserver {
  _WebLocationObserver(this.onChanged);
  final ValueChanged<WebAppLocation> onChanged;
  final List<Route<dynamic>> _routes = [];
  Route<dynamic>? get top => _routes.lastOrNull;
  bool contains(Route<dynamic>? route) =>
      route != null && _routes.contains(route);
  bool isDisplaying(WebAppLocation target) {
    final settings = top?.settings;
    if (settings is WebAppRouteSettings) return settings.location == target;
    return target == WebAppLocation.home && settings is AppRootRouteSettings;
  }
  WebAppLocation get location {
    for (final route in _routes.reversed) {
      final settings = route.settings;
      if (settings is WebAppRouteSettings) return settings.location;
      if (settings is AppRootRouteSettings) return WebAppLocation.home;
    }
    return WebAppLocation.home;
  }

  void _changed() => onChanged(location);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _changed();
  }
}
