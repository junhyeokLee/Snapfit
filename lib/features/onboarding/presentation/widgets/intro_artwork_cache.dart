import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps only artwork actually visited in this introduction. No eager image
/// loads or page keep-alives are needed; exiting releases its own cache leases.
class IntroArtworkCache extends StatefulWidget {
  const IntroArtworkCache({super.key, required this.child});
  final Widget child;

  static IntroArtworkCacheSession? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_IntroArtworkCacheScope>()
      ?.session;

  @override
  State<IntroArtworkCache> createState() => _IntroArtworkCacheState();
}

class _IntroArtworkCacheState extends State<IntroArtworkCache> {
  final _session = IntroArtworkCacheSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _IntroArtworkCacheScope(session: _session, child: widget.child);
}

class _IntroArtworkCacheScope extends InheritedWidget {
  const _IntroArtworkCacheScope({required this.session, required super.child});
  final IntroArtworkCacheSession session;

  @override
  bool updateShouldNotify(_IntroArtworkCacheScope oldWidget) =>
      !identical(session, oldWidget.session);
}

/// A route retains keys, not widgets, image listeners, or decoded image handles.
/// The normal Flutter image cache still responds to system memory pressure.
class IntroArtworkCacheSession {
  // Shared keys may belong to two overlapping intro routes. Remove a key only
  // after the final route releases it, including late key-lookup completions.
  static final _owners = <Object, int>{};

  final _requests = <(ResizeImage, AssetBundle?, double?)>{};
  final _keys = <Object>{};
  bool _disposed = false;

  void remember(ResizeImage provider, ImageConfiguration configuration) {
    if (_disposed) return;
    final request = (
      provider,
      configuration.bundle,
      configuration.devicePixelRatio,
    );
    if (!_requests.add(request)) return;
    unawaited(
      Future<ResizeImageKey>.sync(
        () => provider.obtainKey(configuration),
      ).then<void>(
        (key) {
          if (_disposed) {
            _evictIfUnowned(key);
          } else if (_keys.add(key)) {
            _owners.update(key, (count) => count + 1, ifAbsent: () => 1);
          }
        },
        onError: (Object _, StackTrace _) {
          // Image.errorBuilder owns failures. Let a later successful lookup
          // register its key so it is still cleaned up when this intro closes.
          _requests.remove(request);
        },
      ),
    );
  }

  static void _evictIfUnowned(Object key) {
    if (!_owners.containsKey(key)) {
      PaintingBinding.instance.imageCache.evict(key, includeLive: false);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final key in _keys) {
      final count = _owners[key]!;
      if (count > 1) {
        _owners[key] = count - 1;
      } else {
        _owners.remove(key);
        _evictIfUnowned(key);
      }
    }
    _keys.clear();
    _requests.clear();
  }
}
