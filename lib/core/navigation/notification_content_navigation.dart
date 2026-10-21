import 'dart:async';

enum NotificationContentKind { album, template }

/// Identifiers select a repository read; they never grant access to its result.
class NotificationContentTarget {
  const NotificationContentTarget(this.kind, this.id);
  final NotificationContentKind kind;
  final int id;

  static int? positiveId(Object? value) {
    final text = value?.toString() ?? '';
    if (!RegExp(r'^[0-9]{1,16}$').hasMatch(text)) return null;
    final id = int.tryParse(text);
    return id != null && id > 0 && id <= 9007199254740991 ? id : null;
  }

  static NotificationContentTarget? fromUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'snapfit' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }
    final kind = switch (uri.host.toLowerCase()) {
      'album' => NotificationContentKind.album,
      'template' => NotificationContentKind.template,
      _ => null,
    };
    if (kind == null) return null;
    final key = kind == NotificationContentKind.album
        ? 'albumId'
        : 'templateId';
    final values = uri.queryParametersAll[key];
    if (values == null || values.length != 1) return null;
    final id = positiveId(values.single);
    return id == null ? null : NotificationContentTarget(kind, id);
  }

  static NotificationContentTarget? fromPayload(Map<String, dynamic> data) {
    for (final entry in const {
      'albumId': NotificationContentKind.album,
      'templateId': NotificationContentKind.template,
    }.entries) {
      if (!data.containsKey(entry.key) || data[entry.key] == null) continue;
      final id = positiveId(data[entry.key]);
      return id == null ? null : NotificationContentTarget(entry.value, id);
    }
    final uri = Uri.tryParse(data['deeplink']?.toString() ?? '');
    return uri == null ? null : fromUri(uri);
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationContentTarget &&
      other.kind == kind &&
      other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
}

class NotificationContentOpen {
  NotificationContentOpen._(this.target, this.ownerId, this.revision);
  final NotificationContentTarget target;
  final String ownerId;
  final int revision;
  final _cancelled = Completer<void>();
  Future<void> get cancelled => _cancelled.future;
  void _cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

/// Keeps a tap through splash/login, and invalidates asynchronous work when a
/// newer target or a different session replaces it. No private data is stored.
class NotificationContentNavigation {
  NotificationContentTarget? _pending, _lastOpened;
  String? _pendingOwner, _sessionOwner, _lastOwner;
  NotificationContentOpen? _opening;
  DateTime? _lastOpenedAt;
  int _revision = 0;

  bool get hasPending => _pending != null;

  void observeOwner(String? ownerId) {
    if (_sessionOwner == ownerId) return;
    final previous = _sessionOwner;
    _sessionOwner = ownerId;
    _revision++;
    _opening?._cancel();
    _opening = null;
    if (previous != null ||
        ownerId != null && _pendingOwner != null && _pendingOwner != ownerId) {
      _pending = null;
      _pendingOwner = null;
    }
  }

  void receive(NotificationContentTarget target, {String? ownerId}) {
    if (_pending == target && _pendingOwner == ownerId ||
        _opening?.target == target &&
            (ownerId == null || _opening?.ownerId == ownerId)) {
      return;
    }
    _revision++;
    _pending = target;
    _pendingOwner = ownerId;
    _opening?._cancel();
    _opening = null;
  }

  void cancel() {
    _revision++;
    _pending = null;
    _pendingOwner = null;
    _opening?._cancel();
    _opening = null;
  }

  NotificationContentOpen? take({
    required String? ownerId,
    required String? profileOwnerId,
    required bool navigatorReady,
    required DateTime now,
  }) {
    final target = _pending;
    if (target == null ||
        ownerId == null ||
        profileOwnerId != ownerId ||
        !navigatorReady ||
        _opening != null) {
      return null;
    }
    _pending = null;
    final expectedOwner = _pendingOwner;
    _pendingOwner = null;
    if (expectedOwner != null && expectedOwner != ownerId) return null;
    if (_lastOpened == target &&
        _lastOwner == ownerId &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!) < const Duration(seconds: 2)) {
      return null;
    }
    return _opening = NotificationContentOpen._(target, ownerId, _revision);
  }

  bool isCurrent(
    NotificationContentOpen opening, {
    required String? ownerId,
    required String? profileOwnerId,
  }) =>
      identical(_opening, opening) &&
      opening.revision == _revision &&
      ownerId == opening.ownerId &&
      profileOwnerId == opening.ownerId;

  void finish(
    NotificationContentOpen opening, {
    required bool opened,
    required DateTime now,
  }) {
    if (!identical(_opening, opening)) return;
    _opening = null;
    if (!opened) return;
    _lastOpened = opening.target;
    _lastOwner = opening.ownerId;
    _lastOpenedAt = now;
  }
}
