/// Keeps an order link until both login and the app navigator are ready.
/// Consuming a link never verifies a payment or changes an order.
class OrderDetailNavigation {
  String? _pendingId;
  String? _pendingOwner;
  String? _lastId;
  String? _lastOwner;
  DateTime? _lastOpenedAt;

  bool get hasPending => _pendingId != null;

  /// Another destination supersedes this request. A later deliberate return
  /// to the same order must not inherit the previous duplicate window.
  void cancel() {
    _pendingId = null;
    _pendingOwner = null;
    _lastId = null;
    _lastOwner = null;
    _lastOpenedAt = null;
  }

  void receive(String orderId, {String? ownerId}) {
    final id = orderId.trim();
    if (id.isEmpty || id.length > 200) return;
    _pendingId = id;
    _pendingOwner = ownerId;
  }

  String? take({
    required String? ownerId,
    required bool navigatorReady,
    required DateTime now,
  }) {
    final id = _pendingId;
    if (id == null || ownerId == null || !navigatorReady) return null;
    _pendingId = null;
    final expectedOwner = _pendingOwner;
    _pendingOwner = null;
    if (expectedOwner != null && expectedOwner != ownerId) return null;
    if (_lastId == id &&
        _lastOwner == ownerId &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!) < const Duration(seconds: 2)) {
      return null;
    }
    _lastId = id;
    _lastOwner = ownerId;
    _lastOpenedAt = now;
    return id;
  }
}
