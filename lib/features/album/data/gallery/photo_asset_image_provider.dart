import 'package:flutter/painting.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'browser_photo_asset.dart';

ImageProvider photoAssetImageProvider(
  AssetEntity asset, {
  bool original = false,
}) => asset is BrowserPhotoAsset
    ? MemoryImage(original ? asset.originalBytes : asset.previewBytes)
    : AssetEntityImageProvider(asset);
