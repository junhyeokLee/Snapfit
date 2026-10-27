import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'editor_thumbnail_cache.dart';

/// A lease follows the lazy row's lifetime, rather than every selection rebuild.
class EditorAssetThumbnail extends StatefulWidget {
  const EditorAssetThumbnail({
    super.key,
    required this.asset,
    required this.cache,
    required this.alignment,
    required this.placeholder,
  });

  final AssetEntity asset;
  final EditorThumbnailCache cache;
  final Alignment alignment;
  final Widget placeholder;

  @override
  State<EditorAssetThumbnail> createState() => _EditorAssetThumbnailState();
}

class _EditorAssetThumbnailState extends State<EditorAssetThumbnail> {
  late EditorThumbnailLease _lease;
  late String _assetId;

  void _acquire() {
    final asset = widget.asset;
    _assetId = asset.id;
    _lease = widget.cache.acquire(
      _assetId,
      () => asset.thumbnailDataWithSize(const ThumbnailSize.square(120)),
    );
  }

  @override
  void initState() {
    super.initState();
    _acquire();
  }

  @override
  void didUpdateWidget(EditorAssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.cache, widget.cache) && _assetId == widget.asset.id)
      return;
    _lease.release();
    _acquire();
  }

  @override
  void dispose() {
    _lease.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    // Replacing a photo must not retain the previous FutureBuilder's pixels.
    key: ValueKey((widget.cache, _assetId)),
    future: _lease.future,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null || bytes.isEmpty) return widget.placeholder;
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          alignment: widget.alignment,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 120,
          cacheHeight: 120,
          errorBuilder: (_, __, ___) => widget.placeholder,
        ),
      );
    },
  );
}
