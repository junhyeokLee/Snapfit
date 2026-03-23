import 'dart:collection';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// gs:// 또는 https:// URL을 받아 Firebase Storage에서 표시용 다운로드 URL로 변환해 주는 공용 위젯.
/// - 같은 gs://에 대해서는 앱이 살아 있는 동안 한 번만 getDownloadURL()을 호출하도록 Future를 캐싱한다.
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
      if (urlOrGs.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(urlOrGs);
        final url = await ref.getDownloadURL();
        _touchResolved(urlOrGs, url);
        return url;
      }
      _touchResolved(urlOrGs, urlOrGs);
      return urlOrGs;
    }();

    _touchInFlight(urlOrGs, future);
    future.whenComplete(() => _resolvedUrlFutures.remove(urlOrGs));
    return future;
  }

  Widget _buildCachedNetwork(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      cacheManager: cacheManager,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
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
          error ??
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!urlOrGs.startsWith('gs://')) {
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
