import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// gs:// 또는 https:// URL을 받아 Firebase Storage에서 표시용 다운로드 URL로 변환해 주는 공용 위젯.
/// - 같은 gs://에 대해서는 앱이 살아 있는 동안 한 번만 getDownloadURL()을 호출하도록 Future를 캐싱한다.
class SnapfitImage extends StatelessWidget {
  final String urlOrGs;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;
  final BaseCacheManager? cacheManager;

  const SnapfitImage({
    super.key,
    required this.urlOrGs,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
    this.cacheManager,
  });

  /// gs:// → https:// 변환 Future 캐시
  static final Map<String, Future<String>> _resolvedUrlFutures = {};

  Future<String> _resolveUrl() {
    // 한 번 요청한 gs://는 Future 자체를 캐싱해서, 스와이프/리빌드 시에
    // 매번 Firebase getDownloadURL를 다시 호출하지 않도록 한다.
    return _resolvedUrlFutures.putIfAbsent(urlOrGs, () async {
      if (urlOrGs.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(urlOrGs);
        return ref.getDownloadURL();
      }
      return urlOrGs;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
              );
        }

        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          fit: fit,
          cacheManager: cacheManager,
          placeholder: (_, __) => placeholder ??
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
          errorWidget: (_, __, ___) => error ??
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
        );
      },
    );
  }
}

