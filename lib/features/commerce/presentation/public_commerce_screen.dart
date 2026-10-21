import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/commerce/commerce_policy.dart';
import '../../../core/constants/album_page_policy.dart';
import '../../../core/constants/cover_size.dart';
import '../../../core/navigation/web_app_location.dart';
import '../../../shared/web/web_design.dart';
import '../../album/printing/print_vendor_spec.dart';
import '../data/public_print_catalog.dart';

void openPublicCommerce(BuildContext context, WebAppLocation location) {
  final navigate = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
  if (navigate != null) {
    navigate(location);
  } else {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: WebAppRouteSettings(location),
        builder: (_) => location.page == WebAppPage.printProducts
            ? const PrintProductsScreen()
            : CommercePolicyScreen(
                kind: CommercePolicyKind.values.byName(location.id!),
              ),
      ),
    );
  }
}

String _won(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}원';

/// Public product information: no payment, order or development-order action.
class PrintProductsScreen extends ConsumerStatefulWidget {
  const PrintProductsScreen({super.key});
  @override
  ConsumerState<PrintProductsScreen> createState() =>
      _PrintProductsScreenState();
}

class _PrintProductsScreenState extends ConsumerState<PrintProductsScreen> {
  final _configurationKey = GlobalKey();
  String _sizeId = defaultCoverSize.productId!;
  PrintCoverType _cover = PrintCoverType.soft;
  int _pages = AlbumPagePolicy.minInnerPages;
  String get _productId => _cover == PrintCoverType.hard
      ? _sizeId.replaceFirst('_SOFT', '_HARD')
      : _sizeId;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(publicPrintCatalogProvider);
    final palette = WebPalette.of(context);
    return SnapFitWebShell(
      title: '인쇄 상품·가격',
      showNavigation: false,
      actions: [
        TextButton(
          onPressed: () => WebNavigationScope.maybeOf(
            context,
          )?.onNavigate(WebSection.albums),
          child: const Text('로그인·내 앨범'),
        ),
      ],
      child: SingleChildScrollView(
        key: const ValueKey('public-commerce-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, bounds) {
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusLabel(
                      text: '판매 준비 중',
                      color: palette.brandInk,
                      background: palette.softBrand,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '화면 속의 추억을,\n한 권의 책으로.',
                      style: TextStyle(
                        fontSize: bounds.maxWidth > 800 ? 44 : 32,
                        height: 1.3,
                        letterSpacing: -1.5,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '사진을 고르고 글을 더해 완성하는 나만의 포토북.\n앨범에 맞는 크기와 커버를 살펴보세요.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '현재 상품과 가격을 준비하고 있습니다.\n결제·제작 주문은 받지 않으며, 아래 금액은 확정 전 예정가입니다.',
                      style: TextStyle(fontSize: 14, height: 1.8),
                    ),
                  ],
                );
                const artwork = _BookArtwork(
                  productId: 'REDP_200_SOFT',
                  hero: true,
                );
                return bounds.maxWidth >= 900
                    ? Row(
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 40),
                          const Expanded(child: artwork),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [copy, const SizedBox(height: 28), artwork],
                      );
              },
            ),
            const SizedBox(height: 40),
            WebSurface(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: palette.brandInk),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '판매에 앞서 상품 구성과 실물 품질을 확인하고 있습니다. '
                      '최종 가격과 주문 가능한 일정은 준비가 끝난 뒤 안내합니다. '
                      '지금은 상품과 가격을 살펴보실 수 있으며 결제는 진행되지 않습니다.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),
            const WebPageHeading(
              title: '내 앨범에 맞는 구성 찾기',
              eyebrow: 'PHOTO BOOK',
              description: '5가지 크기 · 소프트커버와 하드커버 · 내지 20~80페이지',
            ),
            const SizedBox(height: 20),
            WebSurface(
              key: _configurationKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final fields = [
                        DropdownButtonFormField<String>(
                          key: ValueKey('public-product-size-$_sizeId'),
                          initialValue: _sizeId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: '크기'),
                          items: [
                            for (final size in coverSizes)
                              DropdownMenuItem(
                                value: size.productId!,
                                child: Text(size.displayName),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _sizeId = value);
                          },
                        ),
                        DropdownButtonFormField<PrintCoverType>(
                          key: ValueKey('public-product-cover-${_cover.name}'),
                          initialValue: _cover,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: '커버'),
                          items: [
                            for (final cover in PrintCoverType.values)
                              DropdownMenuItem(
                                value: cover,
                                child: Text(cover.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _cover = value);
                          },
                        ),
                        DropdownButtonFormField<int>(
                          key: ValueKey('public-product-pages-$_pages'),
                          initialValue: _pages,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '내지 페이지',
                          ),
                          items: [
                            for (
                              var p = AlbumPagePolicy.minInnerPages;
                              p <= AlbumPagePolicy.maxInnerPages;
                              p += AlbumPagePolicy.pageStep
                            )
                              DropdownMenuItem(value: p, child: Text('$p페이지')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _pages = value);
                          },
                        ),
                      ];
                      return bounds.maxWidth >= 760
                          ? Row(
                              children: [
                                for (var i = 0; i < fields.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 16),
                                  Expanded(child: fields[i]),
                                ],
                              ],
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < fields.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 16),
                                  fields[i],
                                ],
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${PrintProduct.forId(_productId)!.label} · 내지 $_pages페이지',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  catalog.when(
                    data: (value) =>
                        _PriceDetail(price: value.price(_productId, _pages)),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => _CatalogError(
                      onRetry: () => ref.invalidate(publicPrintCatalogProvider),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '내지는 표지를 제외한 페이지 수이며 2페이지 단위로 선택합니다. '
                    '사진과 글의 배치, 커버 디자인은 앨범 편집기에서 직접 정합니다.',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),
            const WebPageHeading(
              title: '대표 구성',
              description: '취향에 맞는 구성을 비교해보세요. 모든 상품은 판매 준비 중입니다.',
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, bounds) {
                final width = bounds.maxWidth >= 1000
                    ? (bounds.maxWidth - 40) / 3
                    : bounds.maxWidth >= 660
                    ? (bounds.maxWidth - 20) / 2
                    : bounds.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    for (final example in const [
                      ('REDP_200_SOFT', 20, '일상의 한 권'),
                      ('REDP_200X150_SOFT', 20, '여행의 넓은 장면'),
                      ('REDP_300_HARD', 80, '오래 간직할 큰 기록'),
                    ])
                      SizedBox(
                        width: width,
                        child: _ProductCard(
                          productId: example.$1,
                          pages: example.$2,
                          title: example.$3,
                          price: catalog.asData?.value.price(
                            example.$1,
                            example.$2,
                          ),
                          onSelect: () {
                            setState(() {
                              _sizeId = example.$1.replaceFirst(
                                '_HARD',
                                '_SOFT',
                              );
                              _cover = example.$1.endsWith('_HARD')
                                  ? PrintCoverType.hard
                                  : PrintCoverType.soft;
                              _pages = example.$2;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final target = _configurationKey.currentContext;
                              if (target != null)
                                Scrollable.ensureVisible(
                                  target,
                                  duration: const Duration(milliseconds: 250),
                                  alignment: .08,
                                );
                            });
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 44),
            const WebPageHeading(
              title: '커버와 종이 안내',
              description: '현재 준비 중인 제작 구성이며 최종 재질과 품질은 실물 확인 후 확정합니다.',
            ),
            const SizedBox(height: 20),
            const WebSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '소프트커버',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('유연한 종이 표지에 사진과 글을 인쇄합니다. 표지는 아트지 300g에 무광 코팅하는 구성입니다.'),
                  SizedBox(height: 20),
                  Text(
                    '하드커버',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '단단한 표지를 사진과 글이 인쇄된 종이로 감싸는 구성입니다. 표지 인쇄지는 스노우지 180g, 코팅은 무광 기준입니다.',
                  ),
                  SizedBox(height: 20),
                  Text(
                    '내지와 인쇄',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '유광 캐논전용지 285g에 컬러 양면 인쇄하는 구성입니다. 내지 20~80페이지는 표지를 제외한 쪽수이며 2페이지 단위로 선택합니다.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    '화면의 앨범 이미지는 디자인 예시입니다. 화면 밝기·기기에 따라 인쇄 색상과 차이가 있을 수 있으며, 사진 해상도와 재단 위치는 최종 인쇄 미리보기에서 확인합니다.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),
            const WebPageHeading(title: '제작과 배송 안내'),
            const SizedBox(height: 20),
            WebSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '판매 개시 후 진행되는 순서',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '앨범 편집·최종 확인 → 배송지·최종 금액 확인 → 결제 → 제작 접수 → 제작·출고 → 배송',
                  ),
                  const SizedBox(height: 18),
                  Text(CommercePolicy.dispatchEstimate),
                  const SizedBox(height: 12),
                  const Text(
                    '발송자명은 스냅핏으로 준비합니다. 가격표·거래명세서·홍보물 미동봉은 실물 샘플로 최종 확인할 예정입니다. '
                    '최종 배송비와 도서산간 추가 비용은 운영 조건 확정 후 주문 전에 안내합니다.',
                  ),
                  const SizedBox(height: 16),
                  Text(CommercePolicy.refundSummary),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _PolicyLink(kind: CommercePolicyKind.shipping),
                      _PolicyLink(kind: CommercePolicyKind.refund),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),
            const PublicCommerceFooter(),
          ],
        ),
      ),
    );
  }
}

class _PriceDetail extends StatelessWidget {
  const _PriceDetail({required this.price, this.compact = false});
  final PublicPrintPrice? price;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    final value = price;
    if (value == null) return const Text('예정가 확인이 필요합니다. 현재 주문할 수 없습니다.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '예정가 ${_won(value.retailPrice)}',
          key: compact ? null : const ValueKey('public-selected-price'),
          style: TextStyle(
            fontSize: compact ? 23 : 30,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '부가세·기본 배송비 포함 예정',
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
        const SizedBox(height: 10),
        Text(
          value.orderCodeApproved ? '제작사 접수 준비 확인 · 실물 검수 전' : '제작사 접수 준비 중',
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          const Text(
            '제작비를 반영한 현재 예정가입니다. 최종 판매가·배송비 확정 후 결제 전에 다시 안내합니다.',
            style: TextStyle(fontSize: 13, height: 1.7),
          ),
        ],
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.productId,
    required this.pages,
    required this.title,
    required this.price,
    required this.onSelect,
  });
  final String productId, title;
  final int pages;
  final PublicPrintPrice? price;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) => WebSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BookArtwork(productId: productId),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${PrintProduct.forId(productId)!.label} · $pages페이지',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        _PriceDetail(price: price, compact: true),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: onSelect, child: const Text('이 구성 살펴보기')),
      ],
    ),
  );
}

class _BookArtwork extends StatelessWidget {
  const _BookArtwork({required this.productId, this.hero = false});
  final String productId;
  final bool hero;
  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    return Container(
      height: hero ? 330 : 215,
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(hero ? 36 : 26),
      child: Center(
        child: AspectRatio(
          aspectRatio: PrintProduct.forId(productId)!.aspectRatio,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .13),
                  blurRadius: 18,
                  offset: const Offset(8, 10),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/templates/jeju_travel/images/approved_stock/beach_people.jpg',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .45),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 19,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OUR DAYS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '기억하고 싶은 순간들',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    color: Colors.black.withValues(alpha: .12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    children: [
      const Text('예정가를 불러오지 못했습니다. 결제·주문은 진행되지 않습니다.'),
      TextButton(onPressed: onRetry, child: const Text('가격 다시 불러오기')),
    ],
  );
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.text,
    required this.color,
    required this.background,
  });
  final String text;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class CommercePolicyScreen extends StatelessWidget {
  const CommercePolicyScreen({super.key, required this.kind});
  final CommercePolicyKind kind;
  @override
  Widget build(BuildContext context) {
    final document = CommercePolicy.document(kind);
    final palette = WebPalette.of(context);
    return SnapFitWebShell(
      title: document.title,
      showNavigation: false,
      actions: [
        TextButton(
          onPressed: () =>
              openPublicCommerce(context, WebAppLocation.printProducts),
          child: const Text('인쇄 상품·가격'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WebPageHeading(
              title: document.title,
              description: document.summary,
              eyebrow: document.version,
            ),
            const SizedBox(height: 16),
            Text(
              '시행일: ${document.effectiveDate}',
              style: TextStyle(color: palette.muted),
            ),
            const SizedBox(height: 20),
            if (!document.sections.any(
              (section) => section.content == CommercePolicy.draftNotice,
            )) ...[
              WebSurface(child: Text(CommercePolicy.draftNotice)),
              const SizedBox(height: 24),
            ],
            WebSurface(
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final section in document.sections) ...[
                      Text(
                        section.heading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        section.content,
                        style: const TextStyle(height: 1.9),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const PublicCommerceFooter(),
          ],
        ),
      ),
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.kind});
  final CommercePolicyKind kind;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => openPublicCommerce(
      context,
      WebAppLocation(WebAppPage.policy, kind.name),
    ),
    child: Text(CommercePolicy.document(kind).title),
  );
}

/// The business record remains explicitly incomplete until the owner supplies
/// registered public seller details. Never reuse a private delivery address.
class PublicCommerceFooter extends StatelessWidget {
  const PublicCommerceFooter({super.key});
  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    return Container(
      key: const ValueKey('public-commerce-footer'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () =>
                    openPublicCommerce(context, WebAppLocation.printProducts),
                child: const Text('인쇄 상품·가격'),
              ),
              for (final kind in [
                CommercePolicyKind.terms,
                CommercePolicyKind.privacy,
                CommercePolicyKind.refund,
                CommercePolicyKind.shipping,
                CommercePolicyKind.seller,
              ])
                _PolicyLink(kind: kind),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '스냅핏 · 판매 준비 중',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '사업자등록·통신판매업 신고 또는 면제 여부·판매자 주소·고객센터 정보는 운영 개시 전에 확정하여 공개합니다.\n'
            '현재 실제 결제와 제작 주문은 제공하지 않습니다.',
            style: TextStyle(fontSize: 12, height: 1.8, color: palette.muted),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final opened = await launchUrl(
                Uri(scheme: 'mailto', path: CommercePolicy.contactEmail),
              );
              if (!opened && context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('문의: ${CommercePolicy.contactEmail}'),
                  ),
                );
            },
            icon: const Icon(Icons.mail_outline, size: 16),
            label: const Text('문의 ${CommercePolicy.contactEmail}'),
          ),
        ],
      ),
    );
  }
}
