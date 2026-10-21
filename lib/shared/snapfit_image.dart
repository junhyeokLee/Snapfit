import 'dart:collection';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../core/utils/storage_url_resolver.dart';

/// gs://, supabase:// 또는 https:// URL을 표시용 다운로드 URL로 변환해 주는 공용 위젯.
/// - 같은 storage URI에 대해서는 앱이 살아 있는 동안 반복 resolver 호출을 줄이도록 Future를 캐싱한다.
class SnapfitImage extends StatelessWidget {
  final String urlOrGs;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? error;
  final BaseCacheManager? cacheManager;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final Widget Function(BuildContext, ImageProvider)? imageBuilder;

  @visibleForTesting
  final Future<String> Function(String)? resolveStorageUrlForTesting;
  @visibleForTesting
  final bool? enableWebStorageRecoveryForTesting;

  const SnapfitImage({
    super.key,
    required this.urlOrGs,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.error,
    this.cacheManager,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.imageBuilder,
    this.resolveStorageUrlForTesting,
    this.enableWebStorageRecoveryForTesting,
  });

  /// gs:// → https:// 변환 Future 캐시
  static const int _maxResolvedUrlEntries = 500;
  static const int _maxInFlightEntries = 120;
  static final LinkedHashMap<String, Future<String>> _resolvedUrlFutures =
      LinkedHashMap<String, Future<String>>();
  static final LinkedHashMap<String, String> _resolvedUrls =
      LinkedHashMap<String, String>();

  static void _touchResolved(String key, String value) {
    _resolvedUrls.remove(key);
    _resolvedUrls[key] = value;
    while (_resolvedUrls.length > _maxResolvedUrlEntries) {
      _resolvedUrls.remove(_resolvedUrls.keys.first);
    }
  }

  static void _touchInFlight(String key, Future<String> value) {
    _resolvedUrlFutures.remove(key);
    _resolvedUrlFutures[key] = value;
    while (_resolvedUrlFutures.length > _maxInFlightEntries) {
      _resolvedUrlFutures.remove(_resolvedUrlFutures.keys.first);
    }
  }

  Future<String> _resolveUrl() {
    final cached = _resolvedUrls[urlOrGs];
    if (cached != null && cached.isNotEmpty) {
      _touchResolved(urlOrGs, cached);
      return Future.value(cached);
    }
    final inFlight = _resolvedUrlFutures[urlOrGs];
    if (inFlight != null) {
      _touchInFlight(urlOrGs, inFlight);
      return inFlight;
    }

    final future = () async {
      final url = await (resolveStorageUrlForTesting ?? resolveStorageImageUrl)(
        urlOrGs,
      );
      _touchResolved(urlOrGs, url);
      return url;
    }();

    _touchInFlight(urlOrGs, future);
    // Consume the bookkeeping future's failure too: FutureBuilder owns the
    // actual error UI. Do not remove a newer retry's in-flight resolution.
    void finished() {
      if (identical(_resolvedUrlFutures[urlOrGs], future)) {
        _resolvedUrlFutures.remove(urlOrGs);
      }
    }

    future.then<void>(
      (_) => finished(),
      onError: (Object _, StackTrace __) => finished(),
    );
    return future;
  }

  Widget _buildCachedNetwork(String url, {Widget Function()? failureBuilder}) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      cacheManager: cacheManager,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      imageBuilder: imageBuilder,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) =>
          placeholder ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (_, __, ___) =>
          failureBuilder?.call() ??
          error ??
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStorageUri =
        urlOrGs.startsWith('gs://') || parseSupabaseStorageUri(urlOrGs) != null;
    if ((enableWebStorageRecoveryForTesting ?? kIsWeb) && isStorageUri) {
      return _WebStorageImage(key: ValueKey(urlOrGs), image: this);
    }
    if (!urlOrGs.startsWith('gs://') &&
        parseSupabaseStorageUri(urlOrGs) == null) {
      return _buildCachedNetwork(urlOrGs);
    }

    final resolved = _resolvedUrls[urlOrGs];
    if (resolved != null && resolved.isNotEmpty) {
      return _buildCachedNetwork(resolved);
    }

    return FutureBuilder<String>(
      future: _resolveUrl(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder ??
              Container(
                color: Colors.grey[300],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return error ??
              Container(
                color: Colors.grey[300],
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                ),
              );
        }

        return _buildCachedNetwork(snapshot.data!);
      },
    );
  }
}

/// Browser download failures can outlive a route because its signed URL is
/// shared. Recovery is explicit and bounded to one attempt per user click.
/// Native images and ordinary external URLs keep their existing render path.
class _WebStorageImage extends StatefulWidget {
  const _WebStorageImage({super.key, required this.image});
  final SnapfitImage image;

  @override
  State<_WebStorageImage> createState() => _WebStorageImageState();
}

class _WebStorageImageState extends State<_WebStorageImage> {
  late Future<String> _resolved;
  bool _retrying = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _resolved = widget.image._resolveUrl();
  }

  Future<void> _retry(String? failedUrl) async {
    if (_retrying || !mounted) return;
    setState(() => _retrying = true);
    final image = widget.image;
    // Leave an independently refreshed URL alone. A failed signing request has
    // no download URL; its own failed future has already been removed above.
    if (failedUrl != null &&
        SnapfitImage._resolvedUrls[image.urlOrGs] == failedUrl) {
      SnapfitImage._resolvedUrls.remove(image.urlOrGs);
    }
    try {
      if (failedUrl != null) {
        final provider = ResizeImage.resizeIfNeeded(
          image.memCacheWidth,
          image.memCacheHeight,
          CachedNetworkImageProvider(
            failedUrl,
            maxWidth: image.maxWidthDiskCache,
            maxHeight: image.maxHeightDiskCache,
            cacheManager: image.cacheManager,
          ),
        );
        await provider.evict();
      }
    } catch (_) {
      // A cache cleanup failure must not block a fresh authorized URL request.
    }
    if (!mounted) return;
    setState(() {
      _attempt++;
      _resolved = widget.image._resolveUrl();
      _retrying = false;
    });
  }

  Widget _placeholder() =>
      widget.image.placeholder ??
      Container(
        color: Colors.grey[300],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _failure(String? failedUrl) {
    if (widget.image.error != null) return widget.image.error!;
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final action = _retrying ? null : () => _retry(failedUrl);
            if (bounds.maxWidth < 180 || bounds.maxHeight < 80) {
              return IconButton(
                key: const ValueKey('web-storage-image-retry'),
                tooltip: '사진 다시 불러오기',
                onPressed: action,
                icon: const Icon(Icons.refresh, size: 20),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
              );
            }
            return TextButton.icon(
              key: const ValueKey('web-storage-image-retry'),
              onPressed: action,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('사진 다시 불러오기', style: TextStyle(fontSize: 12)),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _resolved,
    builder: (context, snapshot) {
      if (_retrying || snapshot.connectionState != ConnectionState.done) {
        return _placeholder();
      }
      final url = snapshot.data;
      if (snapshot.hasError || url == null || url.isEmpty)
        return _failure(null);
      return KeyedSubtree(
        key: ValueKey(_attempt),
        child: widget.image._buildCachedNetwork(
          url,
          failureBuilder: () => _failure(url),
        ),
      );
    },
  );
}
