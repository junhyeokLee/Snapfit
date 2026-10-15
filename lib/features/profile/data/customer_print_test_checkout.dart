import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../album/printing/album_print_exporter.dart';
import 'print_dev_checkout.dart';

/// The customer form may run a test only after the authenticated server grants
/// this exact album, revision, product, amount and TEST channel.
class CustomerPrintTestCapability {
  const CustomerPrintTestCapability._({
    required this.albumId,
    required this.reviewedRevision,
  });

  final int albumId;
  final String reviewedRevision;

  static CustomerPrintTestCapability? fromJson(Map<String, dynamic> json) {
    if (json['canTest'] != true) return null;
    if (json['environment'] != 'test' ||
        json['isTest'] != true ||
        json['productionApproved'] != false ||
        json['albumId'] is! int ||
        (json['albumId'] as int) <= 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch('${json['reviewedRevision']}') ||
        json['productId'] != 'REDP_300_HARD' ||
        json['pageCount'] != 80 ||
        json['totalAmount'] != 159900 ||
        json['currency'] != 'KRW' ||
        json['storeId'] != PrintDevCheckoutSession.testStoreId ||
        json['channelKey'] != PrintDevCheckoutSession.testChannelKey) {
      throw const FormatException('customer_print_test_capability_invalid');
    }
    return CustomerPrintTestCapability._(
      albumId: json['albumId'] as int,
      reviewedRevision: json['reviewedRevision'] as String,
    );
  }
}

class CustomerPrintTestOrder {
  const CustomerPrintTestOrder._({
    required this.session,
    required this.albumTitle,
    required this.createdAt,
    required this.recipient,
  });
  final PrintDevCheckoutSession session;
  final String albumTitle;
  final DateTime createdAt;
  final Map<String, dynamic> recipient;

  factory CustomerPrintTestOrder.fromJson(Map<String, dynamic> json) {
    final session = PrintDevCheckoutSession.fromJson(json);
    final title = json['albumTitle'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final rawRecipient = json['recipient'];
    if (title is! String ||
        title.trim().isEmpty ||
        title.length > 500 ||
        createdAt == null ||
        rawRecipient != null && rawRecipient is! Map) {
      throw const FormatException('customer_print_test_order_invalid');
    }
    final recipient = rawRecipient == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rawRecipient as Map);
    if (recipient.entries.any(
      (entry) =>
          !const {
            'name',
            'phone',
            'zipCode',
            'addressLine1',
            'addressLine2',
            'deliveryMemo',
          }.contains(entry.key) ||
          entry.value is! String,
    )) {
      throw const FormatException('customer_print_test_order_invalid');
    }
    return CustomerPrintTestOrder._(
      session: session,
      albumTitle: title,
      createdAt: createdAt,
      recipient: Map.unmodifiable(recipient),
    );
  }
}

/// Preserve the previous administrator test's recovery record. The normal
/// customer form has its own owner-scoped, idempotent TEST recovery record.
class CustomerPrintTestCheckoutStore extends PrintDevCheckoutStore {
  String _key(String owner) => 'snapfit_customer_print_test_pending_v1_$owner';

  @override
  Future<Map<String, dynamic>?> read(String owner) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(owner));
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> write(String owner, Map<String, dynamic> value) async {
    if (!(await (await SharedPreferences.getInstance()).setString(
      _key(owner),
      jsonEncode(value),
    ))) {
      throw const PrintDevCheckoutException('dev_recovery_not_saved');
    }
  }
}

final customerPrintTestCheckoutServiceProvider =
    Provider<CustomerPrintTestCheckoutService>(
      (ref) => CustomerPrintTestCheckoutService(
        PrintDevCheckoutService(
          repository: PrintDevCheckoutRepository(
            ref.watch(supabaseClientProvider),
          ),
          store: CustomerPrintTestCheckoutStore(),
          exporter: AlbumPrintExporter(loadOnlyUsedFonts: true),
        ),
      ),
    );

/// This adapter deliberately cannot produce a production paid receipt or call
/// production checkout. It shares the same strict PDF and TEST receipt checks
/// as the already verified development pipeline.
class CustomerPrintTestCheckoutService {
  CustomerPrintTestCheckoutService(this.development);
  final PrintDevCheckoutService development;

  Future<CustomerPrintTestCapability?> capability({
    required int albumId,
    required String reviewedRevision,
  }) async {
    final capability = CustomerPrintTestCapability.fromJson(
      await development.repository.invoke('capability', {
        'albumId': albumId,
        'reviewedRevision': reviewedRevision,
      }),
    );
    if (capability != null &&
        (capability.albumId != albumId ||
            capability.reviewedRevision != reviewedRevision)) {
      throw const FormatException('customer_print_test_identity_changed');
    }
    return capability;
  }

  Future<PrintDevCheckoutSession?> resume() => development.resume();
  Future<bool> sdkStarted() => development.sdkStarted();

  Future<PrintDevCheckoutSession> prepare({
    required int albumId,
    required String reviewedRevision,
    required Map<String, String> recipient,
  }) => development.prepare(
    albumId: albumId,
    reviewedRevision: reviewedRevision,
    recipient: recipient,
  );

  Future<PrintDevCheckoutSession> prepareFiles(
    PrintDevCheckoutSession session, {
    void Function(String)? onProgress,
  }) => development.prepareFiles(session, onProgress: onProgress);

  Future<PrintDevCheckoutSession> authorize(PrintDevCheckoutSession session) =>
      development.authorize(session);

  Future<void> assertCanLaunch(PrintDevCheckoutSession session) =>
      development.assertCanLaunch(session);

  Future<PrintDevCheckoutSession> status(PrintDevCheckoutSession session) =>
      development.status(session);

  Future<List<CustomerPrintTestOrder>> history() async {
    final raw = await development.repository.invoke('history', const {});
    if (raw['environment'] != 'test' ||
        raw['isTest'] != true ||
        raw['productionApproved'] != false ||
        raw['orders'] is! List ||
        (raw['orders'] as List).length > 50) {
      throw const FormatException('customer_print_test_history_invalid');
    }
    final orders = <CustomerPrintTestOrder>[];
    for (final item in raw['orders'] as List) {
      if (item is! Map || item.containsKey('recipient')) {
        throw const FormatException('customer_print_test_history_invalid');
      }
      orders.add(
        CustomerPrintTestOrder.fromJson(Map<String, dynamic>.from(item)),
      );
    }
    return List.unmodifiable(orders);
  }

  Future<CustomerPrintTestOrder> detail(String runId) async {
    final result = CustomerPrintTestOrder.fromJson(
      await development.repository.invoke('detail', {'runId': runId}),
    );
    if (result.session.runId != runId) {
      throw const FormatException('customer_print_test_identity_changed');
    }
    return result;
  }
}
