import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/album/domain/album_invite_link.dart';
import 'app_root_route_observer.dart';
import 'web_app_location.dart';

/// Website destinations change their content without sliding the shared header
/// away. Native routes and focused editor transitions remain independent.
class WebAppPageRoute<T> extends MaterialPageRoute<T> {
  WebAppPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Starts from the browser address rather than Flutter's default hash route.
/// Both direct paths and existing `#/path` links use the same canonical parser;
/// subsequent browser history updates still come from the platform provider.
class WebAppRouteInformationProvider extends PlatformRouteInformationProvider {
  WebAppRouteInformationProvider({required Uri browserUri, this.onAlbumInvite})
    : _browserUri = browserUri,
      super(
        initialRouteInformation: RouteInformation(
          uri: WebAppLocation.parse(browserUri).uri,
        ),
      ) {
    _receiveAlbumInvite(browserUri);
  }

  final Uri _browserUri;
  final ValueChanged<Uri>? onAlbumInvite;

  bool _receiveAlbumInvite(Uri uri) {
    final resolved = uri.hasScheme ? uri : _browserUri.resolveUri(uri);
    if (onAlbumInvite == null || albumInviteTokenFromUri(resolved) == null) {
      return false;
    }
    onAlbumInvite!(resolved);
    return true;
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    if (_receiveAlbumInvite(routeInformation.uri)) {
      // An invitation opens above the current work through its own router.
      // Replace the capability URL without navigating away from that work.
      routerReportsNewRouteInformation(
        value,
        type: RouteInformationReportingType.neglect,
      );
      return SynchronousFuture(true);
    }
    return super.didPushRouteInformation(routeInformation);
  }

  bool _reportedInitialRoute = false;

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    // Flutter's engine still starts at `/` for direct paths under the hash
    // strategy. Replace that entry instead of adding an extra startup entry
    // whose first browser Back would incorrectly reopen the home page.
    final reportType = _reportedInitialRoute
        ? type
        : RouteInformationReportingType.neglect;
    _reportedInitialRoute = true;
    super.routerReportsNewRouteInformation(routeInformation, type: reportType);
  }
}

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
  bool isDisplayingLocation(WebAppLocation location) =>
      _observer.isDisplaying(location);
  bool containsLocation(WebAppLocation location) =>
      _observer.routeFor(location) != null;

  /// Called only after the application has checked the requested account and
  /// destination. It never pops through an editor or a modal to reach a list.
  bool updateDisplayedLocation(WebAppLocation location) {
    final settings = _observer.top?.settings;
    if (settings is! WebAppRouteSettings ||
        settings.controller?.update(location) != true) {
      return false;
    }
    finishInitialNavigation();
    return true;
  }

  @override
  void dispose() {
    _observer.dispose();
    super.dispose();
  }

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

  /// Session changes must remove private routes immediately. Public product
  /// and policy pages can then reopen without belonging to either account.
  void resetForSessionChange({WebAppLocation? pendingLocation}) {
    final target = pendingLocation ?? _observer.location;
    final keep = target.isPublic ? target : null;
    _requestPending = true;
    if (keep != null) _location = keep;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (keep == null) {
      restoreObservedLocation();
    } else {
      onLocationRequested(keep);
      notifyListeners();
    }
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

  /// Reveals an already mounted destination rather than recreating its search,
  /// filters and scroll state. The same exit guards apply to every page above
  /// it; a save prompt must not be mistaken for a successful navigation.
  Future<bool> returnToLocation(WebAppLocation location) async {
    final destination = _observer.routeFor(location);
    final navigator = navigatorKey.currentState;
    if (destination == null || navigator == null) return false;
    while (_observer.top != destination && navigator.canPop()) {
      final previous = _observer.top;
      await navigator.maybePop();
      if (_observer.contains(previous)) {
        restoreObservedLocation();
        return false;
      }
    }
    return _observer.isDisplaying(location);
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
  final Map<Route<dynamic>, WebAppRouteController> _controllers = {};

  void _watch(Route<dynamic> route) {
    final settings = route.settings;
    if (settings is WebAppRouteSettings && settings.controller != null) {
      _controllers[route] = settings.controller!;
      settings.controller!.addListener(_changed);
    }
  }

  void _unwatch(Route<dynamic> route) {
    _controllers.remove(route)?.removeListener(_changed);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_changed);
    }
    _controllers.clear();
  }

  Route<dynamic>? get top => _routes.lastOrNull;
  bool contains(Route<dynamic>? route) =>
      route != null && _routes.contains(route);
  Route<dynamic>? routeFor(WebAppLocation target) {
    for (final route in _routes.reversed) {
      final settings = route.settings;
      if (settings is WebAppRouteSettings && settings.location == target) {
        return route;
      }
      if (target == WebAppLocation.home && settings is AppRootRouteSettings) {
        return route;
      }
    }
    return null;
  }

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
    _watch(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _unwatch(route);
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _unwatch(route);
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _unwatch(oldRoute);
    if (newRoute != null) _watch(newRoute);
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
