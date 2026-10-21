import 'package:flutter/widgets.dart';

enum WebAppPage {
  home,
  login,
  albums,
  create,
  aiCreate,
  album,
  editor,
  print,
  orders,
  order,
  testOrder,
  account,
  designs,
  materials,
  template,
  library,
  notifications,
  printProducts,
  policy,
}

/// Public browser locations contain identifiers only. Access to each object is
/// checked again by the authenticated repository, never granted by this path.
class WebAppLocation {
  const WebAppLocation(this.page, [this.id]);
  static const home = WebAppLocation(WebAppPage.home);
  static const login = WebAppLocation(WebAppPage.login);
  static const albums = WebAppLocation(WebAppPage.albums);
  static const create = WebAppLocation(WebAppPage.create);
  static const aiCreate = WebAppLocation(WebAppPage.aiCreate);
  static const orders = WebAppLocation(WebAppPage.orders);
  static const account = WebAppLocation(WebAppPage.account);
  static const designs = WebAppLocation(WebAppPage.designs);
  static const materials = WebAppLocation(WebAppPage.materials);
  static const library = WebAppLocation(WebAppPage.library);
  static const notifications = WebAppLocation(WebAppPage.notifications);
  static const printProducts = WebAppLocation(WebAppPage.printProducts);
  static const policySlugs = {
    'terms',
    'privacy',
    'refund',
    'shipping',
    'seller',
    'marketing',
    'opensource',
  };
  final WebAppPage page;
  final String? id;

  /// Only informational pages are public. Album/order identifiers still require
  /// server-validated authentication and ownership checks.
  bool get isPublic =>
      page == WebAppPage.home ||
      page == WebAppPage.login ||
      page == WebAppPage.designs ||
      page == WebAppPage.template ||
      page == WebAppPage.printProducts ||
      (page == WebAppPage.policy && policySlugs.contains(id));

  Uri get uri => Uri(
    path: switch (page) {
      WebAppPage.home => '/',
      WebAppPage.login => '/login',
      WebAppPage.albums => '/albums',
      WebAppPage.create => '/create',
      WebAppPage.aiCreate => '/create/ai',
      WebAppPage.album => '/albums/$id',
      WebAppPage.editor => '/albums/$id/edit',
      WebAppPage.print => '/albums/$id/print',
      WebAppPage.orders => '/orders',
      WebAppPage.order => '/orders/$id',
      WebAppPage.testOrder => '/test-orders/$id',
      WebAppPage.account => '/account',
      WebAppPage.designs => '/designs',
      WebAppPage.materials => '/designs/materials',
      WebAppPage.template => '/designs/templates/$id',
      WebAppPage.library => '/library',
      WebAppPage.notifications => '/notifications',
      WebAppPage.printProducts => '/print-products',
      WebAppPage.policy => '/policies/$id',
    },
  );

  static WebAppLocation parse(Uri source) {
    final uri = source.fragment.startsWith('/')
        ? Uri.tryParse(source.fragment) ?? Uri(path: '/')
        : source;
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return home;
    if (parts.length == 1 && parts[0] == 'login') return login;
    if (parts.length == 1 && parts[0] == 'albums') return albums;
    if (parts.length == 1 && parts[0] == 'print-products') return printProducts;
    if (parts.length == 2 &&
        parts[0] == 'policies' &&
        policySlugs.contains(parts[1])) {
      return WebAppLocation(WebAppPage.policy, parts[1]);
    }
    if (parts.length == 1 && parts[0] == 'create') return create;
    if (parts.length == 2 && parts[0] == 'create' && parts[1] == 'ai')
      return aiCreate;
    if (parts.length == 1 && parts[0] == 'orders') return orders;
    if (parts.length == 1 && parts[0] == 'account') return account;
    if (parts.length == 1 && parts[0] == 'designs') return designs;
    if (parts.length == 2 && parts[0] == 'designs') {
      if (parts[1] == 'templates') return designs;
      if (parts[1] == 'materials') return materials;
    }
    if (parts.length == 3 && parts[0] == 'designs' && parts[1] == 'templates') {
      final id = int.tryParse(parts[2]);
      if (id != null && id != 0 && id.abs() <= 9007199254740991) {
        return WebAppLocation(WebAppPage.template, '$id');
      }
      return home;
    }
    if (parts.length == 1 && parts[0] == 'library') return library;
    if (parts.length == 1 && parts[0] == 'notifications') return notifications;
    if (parts.length >= 2 && parts[0] == 'albums') {
      final id = int.tryParse(parts[1]);
      if (id == null || id <= 0 || id > 9007199254740991) return home;
      if (parts.length == 2) return WebAppLocation(WebAppPage.album, '$id');
      if (parts.length == 3 && parts[2] == 'edit') {
        return WebAppLocation(WebAppPage.editor, '$id');
      }
      if (parts.length == 3 && parts[2] == 'print') {
        return WebAppLocation(WebAppPage.print, '$id');
      }
    }
    if (parts.length == 2 &&
        RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(parts[1])) {
      if (parts[0] == 'orders')
        return WebAppLocation(WebAppPage.order, parts[1]);
      if (parts[0] == 'test-orders' &&
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
          ).hasMatch(parts[1])) {
        return WebAppLocation(WebAppPage.testOrder, parts[1]);
      }
    }
    return home;
  }

  @override
  bool operator ==(Object other) =>
      other is WebAppLocation && page == other.page && id == other.id;
  @override
  int get hashCode => Object.hash(page, id);
}

/// No named route: the Router alone owns browser history. Native navigation
/// keeps its existing animations and stack.
class WebAppRouteSettings extends RouteSettings {
  const WebAppRouteSettings(WebAppLocation location, {this.controller})
    : _location = location;
  final WebAppLocation _location;
  final WebAppRouteController? controller;
  WebAppLocation get location => controller?.value ?? _location;
}

/// A mounted list can change its browser address without losing its search,
/// filters or scroll position. Only the declared pages can share this route.
class WebAppRouteController extends ValueNotifier<WebAppLocation> {
  WebAppRouteController(super.value, {required Set<WebAppPage> pages})
    : _pages = Set.unmodifiable(pages);

  final Set<WebAppPage> _pages;

  bool accepts(WebAppLocation location) => _pages.contains(location.page);

  bool update(WebAppLocation location) {
    if (!accepts(location)) return false;
    value = location;
    return true;
  }
}
