import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../album/printing/print_vendor_spec.dart';
import '../../../config/env.dart';
import '../../../core/constants/album_page_policy.dart';

/// Public retail information only. Supplier cost, margin and management codes
/// never belong in this model or its anonymous endpoint.
class PublicPrintPrice {
  const PublicPrintPrice({
    required this.productId,
    required this.pageCount,
    required this.retailPrice,
    required this.shippingFee,
    required this.orderCodeApproved,
  });
  final String productId;
  final int pageCount, retailPrice;
  final int? shippingFee;
  final bool orderCodeApproved;

  factory PublicPrintPrice.fromJson(Map<String, dynamic> json) {
    final product = PrintProduct.forId(json['productId'] as String?);
    final pages = json['pageCount'];
    final price = json['retailPrice'];
    final shipping = json['shippingFee'];
    if (product == null ||
        pages is! int ||
        !AlbumPagePolicy.isValid(pages) ||
        price is! int ||
        price <= 0 ||
        price > 10000000 ||
        (shipping != null &&
            (shipping is! int || shipping < 0 || shipping > 100000)) ||
        json['priceIsEstimate'] != true ||
        json['shippingIncluded'] != true ||
        json['orderCodeApproved'] is! bool) {
      throw const FormatException('public_print_price_invalid');
    }
    return PublicPrintPrice(
      productId: product.id,
      pageCount: pages,
      retailPrice: price,
      shippingFee: shipping as int?,
      orderCodeApproved: json['orderCodeApproved'] == true,
    );
  }
}

class PublicPrintCatalog {
  const PublicPrintCatalog({required this.generatedAt, required this.items});
  final DateTime generatedAt;
  final List<PublicPrintPrice> items;
  factory PublicPrintCatalog.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse('${json['generatedAt'] ?? ''}');
    final values = json['items'];
    if (json['currency'] != 'KRW' ||
        json['salesOpen'] != false ||
        date == null ||
        values is! List ||
        values.isEmpty ||
        values.length > 310) {
      throw const FormatException('public_print_catalog_invalid');
    }
    final prices = values
        .map(
          (raw) =>
              PublicPrintPrice.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .toList(growable: false);
    if (prices.map((v) => '${v.productId}:${v.pageCount}').toSet().length !=
        prices.length) {
      throw const FormatException('public_print_price_duplicate');
    }
    return PublicPrintCatalog(
      generatedAt: date,
      items: List.unmodifiable(prices),
    );
  }
  PublicPrintPrice? price(String productId, int pageCount) {
    for (final value in items) {
      if (value.productId == productId && value.pageCount == pageCount)
        return value;
    }
    return null;
  }
}

final publicPrintCatalogProvider =
    FutureProvider.autoDispose<PublicPrintCatalog>((ref) async {
      // Only the public client key is sent. Expired customer sessions cannot
      // prevent anonymous product browsing or initiate an auth refresh here.
      final client = http.Client();
      ref.onDispose(client.close);
      final response = await client
          .get(
            Uri.parse('${Env.supabaseUrl}/functions/v1/print-public-catalog'),
            headers: {
              'apikey': Env.supabaseAnonKey,
              'Authorization': 'Bearer ${Env.supabaseAnonKey}',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200)
        throw const FormatException('public_print_catalog_unavailable');
      return PublicPrintCatalog.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    });
