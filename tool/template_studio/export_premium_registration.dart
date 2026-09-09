import 'dart:convert';
import 'dart:io';

import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';

String premiumVolumeDraftSql() {
  final records = [
    for (final product in pendingPremiumVolumeProducts)
      {
        'product_key': product.productKey,
        'asset_id': product.assetId,
        'kind': product.kind,
        'title': product.title,
      },
  ];
  final json = jsonEncode(records).replaceAll("'", "''");
  return '''-- Registration only: no live price, publication, or customer charge.
-- Existing rows, including already configured prices, are never overwritten.
insert into public.point_shop_products
  (product_key, asset_id, kind, title, point_price, is_active)
select product_key, asset_id, kind, title, null, false
from jsonb_to_recordset('$json'::jsonb)
  as draft(product_key text, asset_id text, kind text, title text)
on conflict (product_key) do nothing
returning product_key, title, point_price, is_active;
''';
}

/// Produces native deliverables and a rights-review inventory, not a deploy or
/// proof of commercial clearance. Run through the focused Flutter test export.
Map<String, dynamic> exportPremiumRegistration(Directory output) {
  output.createSync(recursive: true);
  final products = <Map<String, dynamic>>[];
  for (final volume in PremiumVolume.values) {
    final editions = <Map<String, dynamic>>[];
    final assets = <String>{};
    final fonts = <String>{};
    final materialKeys = <String>{};
    for (final count in volume.pageCounts) {
      for (final aspect in CollectionAspect.values) {
        final document = volume.document(aspect, innerPages: count);
        materialKeys.addAll(templateVisualMaterialKeys(document));
        final pages = templateDocumentPages(document);
        if (pages.length != count + 1) {
          throw StateError('${volume.id}: incomplete edition');
        }
        for (final page in pages) {
          for (final layer in page['layers'] as List) {
            final image = layer['imageUrl'];
            if (image is String && image.startsWith('asset:')) {
              final path = image.substring('asset:'.length);
              if (!File(path).existsSync()) throw StateError('Missing $path');
              assets.add(path);
            }
            final style = layer['style'];
            final font = style is Map ? style['fontFamily'] : null;
            if (font is String) fonts.add(font);
          }
        }
        final path = '${volume.id}/$count/${aspect.name}.json';
        final file = File('${output.path}/$path');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(document));
        editions.add({
          'innerPages': count,
          'coverPages': 1,
          'aspect': aspect.name,
          'document': path,
        });
      }
    }
    products.add({
      'productKey': premiumVolumeProductKey(volume),
      'title': volume.title,
      'category': volume.category,
      'status': 'registered-draft',
      'launchPointPrice': premiumVolumeLaunchPointPrice,
      'pricingRevision': pointShopPricingRevision,
      'pointPrice': null,
      'isActive': false,
      'proposedEntitlement': 'one-account-all-listed-editions-and-aspects',
      'includesPrinting': false,
      'editions': editions,
      'localAssets': assets.toList()..sort(),
      'fontFamilies': fonts.toList()..sort(),
      'visualMaterialProductKeys': materialKeys.toList()..sort(),
      'materialEntitlementStatus': 'proposed-not-granted',
      'releaseGates': {
        'design': 'approved',
        'price': 'launch-price-set-sale-held',
        'commerceIntegration': 'pending-store-and-editor-delivery',
        'storePaymentQA': 'pending',
        'distributionRights': 'pending-asset-and-font-review',
        'printProof': 'pending',
      },
    });
  }
  final manifest = <String, dynamic>{
    'version': 1,
    'products': products,
    'note': 'Local draft export; not evidence of remote registration or sale.',
  };
  File(
    '${output.path}/manifest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  File(
    '${output.path}/register-drafts.sql',
  ).writeAsStringSync(premiumVolumeDraftSql());
  return manifest;
}
