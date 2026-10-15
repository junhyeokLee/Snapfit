import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/printing/print_vendor_spec.dart';
import 'package:snap_fit/features/album/presentation/views/album_category_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_preview_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_frozen_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_quota.dart';
import 'package:snap_fit/features/notification/domain/entities/app_notification_item.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/notification/presentation/views/notification_screen.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/presentation/views/order_history_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/admin_point_shop_management_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/terms_policy_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_full_screen_view.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'auth_gate_test.dart' show FakeHomeViewModel;
import 'my_page_screen_test.dart' show FakeAuthViewModel;

class _Orders extends Mock implements OrderRepository {}

class _Members extends Mock implements AlbumMemberRepository {}

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _photo =
    'assets/templates/original_editorial/images/cover_cinema_dance.png';
const _albumTitle = '우리의 여름, 오래 간직할 장면들';

Map<String, dynamic> _document(double ratio) => {
  'pages': [
    for (var index = 0; index < 5; index++)
      {
        'index': index,
        'isCover': index == 0,
        'backgroundColor': 0xfff3f6f5,
        'layers': [
          {
            'id': 'audit-photo-$index',
            'type': 'image',
            'x': 0.0,
            'y': 0.0,
            'width': 1.0,
            'height': 1.0,
            'rotation': 0.0,
            'payload': {'originalUrl': 'asset:$_photo'},
            'zIndex': 0,
          },
        ],
      },
  ],
};

Album _album(int id, double ratio, {bool shared = false}) => Album(
  id: id,
  title: '$_albumTitle $id',
  ratio: '$ratio',
  coverTheme: 'classic',
  coverLayersJson: jsonEncode(_document(ratio)),
  totalPages: 5,
  targetPages: 24,
  userId: shared ? 'friend' : 'qa',
  createdAt: '2026-10-07T10:00:00',
);

final _order = OrderHistoryItem(
  orderId: 'SNAPFIT-REVIEW-20261007',
  title: _albumTitle,
  amount: 59900,
  pageCount: 24,
  status: 'SHIPPING',
  statusLabel: '배송중',
  progress: .75,
  orderedAt: DateTime(2026, 10, 7, 10),
  recipientName: '테스트 수령인',
  recipientPhone: '010-0000-0000',
  zipCode: '00000',
  addressLine1: '검토용 주소이며 실제 배송 정보가 아닙니다',
  addressLine2: '샘플 주소',
  deliveryMemo: '문 앞에 놓아 주세요',
  paymentMethod: '검토용 결제 자료',
  courier: 'CJ대한통운',
  trackingNumber: '000000000000',
  paymentConfirmedAt: DateTime(2026, 10, 7, 10, 5),
  printAcceptedAt: DateTime(2026, 10, 7, 11),
  shippedAt: DateTime(2026, 10, 7, 12),
  printProductSnapshot: PrintProduct.forId('REDP_250X200_SOFT')!.toJson(),
  pricingVersion: 'PRINT_REDP_MULTISIZE_V2',
);

// The same real widgets are regression-tested even when image export is disabled.
void main() {
  _PaintBinding();
  const exportImages = bool.fromEnvironment('ALL_SCREENS_QA');
  const revision = String.fromEnvironment(
    'ALL_SCREENS_REVISION',
    defaultValue: '-after',
  );
  final observations = <Map<String, Object?>>[];
  setUpAll(() async {
    await loadCreationFonts();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDownAll(() {
    if (!exportImages) return;
    final dir = Directory('output/all-screens-qa')..createSync(recursive: true);
    File('${dir.path}/observations$revision.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(observations),
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('capture secondary screens $size dark=$dark', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = size.width > size.height
            ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
            : const FakeViewPadding(top: 24, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final orders = _Orders();
        final members = _Members();
        when(() => members.invite(7, role: any(named: 'role'))).thenAnswer(
          (_) async => const InviteLinkResponse(
            albumId: 7,
            token: 'review',
            link: 'https://snapfit.example/invite/review',
          ),
        );
        when(() => orders.fetchMyOrders()).thenAnswer((_) async => [_order]);
        when(() => orders.fetchMyPrintOrderProgress(_order.orderId)).thenAnswer(
          (_) async => PrintOrderProgress(
            orderId: _order.orderId,
            customerStage: 'SHIPPING',
            preflightPassed: true,
            requiresAction: false,
            shippedAt: _order.shippedAt,
            courier: _order.courier,
            trackingNumber: _order.trackingNumber,
          ),
        );
        when(
          () => orders.fetchMyOrdersPage(
            statuses: any(named: 'statuses'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          ),
        ).thenAnswer(
          (_) async => OrderPageResult(
            items: [_order],
            page: 0,
            size: 20,
            totalPages: 1,
            totalElements: 1,
            hasNext: false,
          ),
        );
        when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
          (_) async => PrintCheckoutReadiness(
            canPay: false,
            status: 'PREPARING',
            reasonCode: 'print_sales_not_ready',
            message: '디자인 검토용 미리보기입니다.',
            quote: OrderQuoteResult.fromJson({
              'pageCount': 24,
              'amount': 59900,
              'sourcePageCount': 4,
              'addedBlankPageCount': 20,
              'productCode': 'REDP_250X200_SOFT',
              'printProduct': PrintProduct.forId('REDP_250X200_SOFT')!.toJson(),
              'priceIsEstimate': true,
              'specMissing': true,
            }),
          ),
        );
        when(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).thenAnswer(
          (_) async => {
            'album': {
              'id': 7,
              'title': _albumTitle,
              'ratio': 1.25,
              'cover_theme': 'classic',
              'cover_layers_json': {
                ..._document(1.25),
                'printProduct': PrintProduct.forId(
                  'REDP_250X200_SOFT',
                )!.toJson(),
              },
            },
            'pages': [],
          },
        );
        final key = GlobalKey();
        final id = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
        final warnings = <String>[];
        void collectErrors() {
          Object? error;
          while ((error = tester.takeException()) != null) {
            warnings.add(error.toString());
          }
        }

        Future<void> mount(Widget screen) async {
          warnings.clear();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: ProviderScope(
                retry: (_, __) => null,
                overrides: [
                  authViewModelProvider.overrideWith(
                    () => FakeAuthViewModel(
                      const UserInfo(
                        id: 'qa',
                        name: '스냅핏',
                        email: 'snapfit@example.com',
                        provider: 'kakao',
                      ),
                    ),
                  ),
                  homeViewModelProvider.overrideWith(
                    () => FakeHomeViewModel([]),
                  ),
                  myPointBalanceProvider.overrideWith((ref) async => 2400),
                  myStorageQuotaProvider.overrideWith(
                    (ref) async => StorageQuotaStatus.fromJson({}),
                  ),
                  myOrderSummaryProvider.overrideWith(
                    (ref) async => OrderSummaryResult.fromJson({}),
                  ),
                  myOrderStatusBadgesProvider.overrideWith(
                    (ref) async => const OrderStatusBadges.zero(),
                  ),
                  pointShopAdminAccessProvider.overrideWithValue(false),
                  orderRepositoryProvider.overrideWithValue(orders),
                  albumMemberRepositoryProvider.overrideWithValue(members),
                  notificationInboxProvider.overrideWith(
                    (ref) async => [
                      AppNotificationItem(
                        id: 1,
                        type: 'album_invite',
                        title: '함께 만들 앨범에 초대받았어요',
                        body: '앨범에서 사진을 추가하고 함께 추억을 남겨 보세요.',
                        createdAt: DateTime(2026, 10, 7),
                        isRead: false,
                      ),
                    ],
                  ),
                  notificationRetentionDaysProvider.overrideWith(
                    (ref) async => 90,
                  ),
                ],
                child: ScreenUtilInit(
                  designSize: const Size(390, 844),
                  builder: (_, __) => MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(
                          size.width == 648 ? 1.3 : 1,
                        ),
                      ),
                      child: child!,
                    ),
                    home: screen,
                  ),
                ),
              ),
            ),
          );
          for (var frame = 0; frame < 18; frame++) {
            await tester.pump(const Duration(milliseconds: 80));
            collectErrors();
          }
          await tester.runAsync(() async {
            for (final element in find.byType(Image).evaluate()) {
              final provider = (element.widget as Image).image;
              if (provider is AssetImage || provider is MemoryImage) {
                await precacheImage(provider, element);
              }
            }
          });
          await tester.pump();
          collectErrors();
        }

        Future<void> capture(String name) async {
          await tester.pump(const Duration(milliseconds: 32));
          collectErrors();
          expect(warnings, isEmpty, reason: '$name at $size dark=$dark');
          if (!exportImages) return;
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('output/all-screens-qa')
              ..createSync(recursive: true);
            File(
              '${dir.path}/$name-$id$revision.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
          observations.add({
            'screen': name,
            'size': '${size.width.toInt()}x${size.height.toInt()}',
            'dark': dark,
            'layoutErrors': List.of(warnings),
          });
        }

        await mount(
          AlbumInviteScreen(
            albumId: 7,
            albumTitle: _albumTitle,
            album: _album(7, 1.25),
          ),
        );
        await capture('invite');
        await tester.drag(
          find.byKey(const ValueKey('inviteContent')),
          const Offset(0, -650),
        );
        await capture('invite-bottom');
        await mount(
          const PrintOrderPreviewScreen(albumId: 7, albumTitle: _albumTitle),
        );
        await capture('print-preview');
        expect(
          find.byKey(const ValueKey('print-preview-page')),
          findsOneWidget,
        );
        await tester.drag(
          find.byType(SingleChildScrollView).evaluate().isNotEmpty
              ? find.byType(SingleChildScrollView).first
              : find.byType(ListView).first,
          const Offset(0, -600),
        );
        await capture('print-preview-middle');
        await mount(const OrderHistoryScreen());
        await capture('orders');
        await tester.tap(find.text(_albumTitle));
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 80));
          collectErrors();
        }
        await capture('order-detail');
        expect(find.textContaining('250×200'), findsWidgets);
        expect(find.textContaining('200×200mm 소프트커버'), findsNothing);
        final detailScroll = find.byType(ListView).last;
        await tester.drag(detailScroll, const Offset(0, -800));
        await capture('order-detail-bottom');
        await mount(
          AlbumCategoryScreen(
            category: AlbumCategory.recent,
            initialAlbums: [_album(1, 1), _album(2, .75), _album(3, 1.3333)],
            currentUserId: 'qa',
          ),
        );
        await capture('album-list');
        await mount(
          AlbumCategoryScreen(
            category: AlbumCategory.shared,
            initialAlbums: [
              _album(1, 1, shared: true),
              _album(2, .75, shared: true),
              _album(3, 1.3333, shared: true),
            ],
            currentUserId: 'qa',
          ),
        );
        await capture('shared-list');
        await mount(const TermsPolicyScreen());
        await capture('policies');
        await mount(
          const TermsPolicyScreen(initialDocType: TermsPolicyDocType.privacy),
        );
        await capture('policy-detail');
        await mount(const SupportInquiryScreen());
        await capture('support');
        await mount(const MyPageScreen());
        await capture('profile');
        await mount(const NotificationScreen());
        await capture('inbox');
        await mount(
          AlbumFrozenScreen(
            album: _album(7, 1.25),
            onClose: () {},
            onOrder: () {},
          ),
        );
        await capture('completion');
        await mount(
          const TemplateFullScreenView(
            parsedPages: [],
            previewImages: ['asset:$_photo'],
            designCanvasSize: Size(500, 500),
          ),
        );
        await capture('template-fullscreen');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        collectErrors();
      });
    }
  }
}
