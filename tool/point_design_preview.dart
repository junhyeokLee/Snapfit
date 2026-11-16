import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/config/env.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/web_point_topup_repository.dart';
import 'package:snap_fit/features/billing/domain/web_point_topup.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local design QA only; never imported by lib/main.dart. The normal web engine
/// loads the application's bundled fonts, rather than widget-test FontLoader.
/// Query options: ?dark=1&history=1. Resize the browser for responsive QA.
const _owner = '11111111-1111-4111-8111-111111111111';
const _catalog = WebPointCatalog(
  testAvailable: true,
  liveAvailable: false,
  environment: 'test',
  products: [
    WebPointProduct(
      id: 'snapfit_points_2500',
      title: '2,500P',
      points: 2500,
      amount: 2200,
    ),
    WebPointProduct(
      id: 'snapfit_points_8000',
      title: '8,000P',
      points: 8000,
      amount: 5900,
    ),
    WebPointProduct(
      id: 'snapfit_points_18000',
      title: '18,000P',
      points: 18000,
      amount: 11900,
    ),
  ],
);
final _ledger = [
  PointLedgerEntry(
    id: 5,
    createdAt: DateTime.utc(2026, 10, 29, 6),
    amountDelta: -450,
    reason: 'DIGITAL_ITEM_PURCHASE',
  ),
  PointLedgerEntry(
    id: 4,
    createdAt: DateTime.utc(2026, 10, 28, 5),
    amountDelta: 2500,
    reason: 'POINT_PURCHASE',
  ),
  PointLedgerEntry(
    id: 3,
    createdAt: DateTime.utc(2026, 10, 27, 6),
    amountDelta: -700,
    reason: 'AI_ALBUM_DRAFT_CHARGE',
  ),
];

// Implementations deliberately have no HTTP, token store or auth lifecycle.
// Any unexpected API access fails locally instead of reaching a real account.
class _PreviewAuth implements GoTrueClient {
  @override
  User get currentUser => User(
    id: _owner,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-29',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Design preview cannot access authentication APIs.');
}

class _PreviewClient implements SupabaseClient {
  @override
  final GoTrueClient auth = _PreviewAuth();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Design preview cannot access Supabase APIs.');
}

class _PreviewTopups extends WebPointTopupRepository {
  _PreviewTopups() : super(_PreviewClient());

  @override
  Future<WebPointCatalog> catalog(String owner) async => _catalog;

  @override
  Future<List<WebPointTopup>> history(String owner) async => const [];

  @override
  Future<WebPointTopup> prepare(
    String owner,
    String requestId,
    WebPointProduct product, {
    String environment = 'test',
  }) => throw StateError('Design preview cannot prepare a payment.');
}

void main() {
  const profilePreview = bool.fromEnvironment('SNAPFIT_POINT_DESIGN_PREVIEW');
  if (!(kDebugMode || (kProfileMode && profilePreview)) || !kIsWeb) {
    throw StateError('This design preview requires a local QA browser build.');
  }
  if (Env.webPointTopupTestEnabled || webPointTopupLiveCheckoutReleased) {
    throw StateError('Design preview requires both checkout gates closed.');
  }
  final query = Uri.base.queryParameters;
  final dark = query['dark'] == '1';
  final history = query['history'] == '1';
  runApp(
    ProviderScope(
      overrides: [
        visibleOrderOwnerProvider.overrideWithValue(_owner),
        webPointTopupRepositoryProvider.overrideWithValue(_PreviewTopups()),
        myPointBalanceProvider.overrideWith((_) async => 12450),
        myPointLedgerProvider.overrideWith((_) async => _ledger),
        pointPurchaseServiceProvider.overrideWith(
          (_) =>
              throw StateError('Design preview cannot start native billing.'),
        ),
      ],
      child: MaterialApp(
        title: 'SnapFit · 포인트 디자인 미리보기',
        debugShowCheckedModeBanner: false,
        theme: SnapFitWebTheme.from(
          dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        ),
        home: WebNavigationScope(
          onNavigate: (_) {},
          onNotifications: () {},
          onPublicNavigate: (_) {},
          child: BillingManagementScreen(
            initialPointsTabIndex: history ? 1 : 0,
          ),
        ),
      ),
    ),
  );
}
