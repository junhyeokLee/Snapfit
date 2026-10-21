import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../shared/web/web_design.dart';

import '../../../core/constants/snapfit_colors.dart';
import '../../../shared/widgets/experience_form_style.dart';
import '../domain/point_shop_product.dart';
import 'point_shop_artwork.dart';
import '../../../shared/widgets/album_stage_style.dart';
import '../../store/presentation/widgets/material_original_preview.dart';

enum PointShopPurchaseAction { buy, topUp }

Future<T?> _showPointShopDialog<T>({required BuildContext context, required WidgetBuilder builder}) {
  if (kIsWeb) return showWebAwareDialog<T>(context: context, builder: builder, maxWidth: 920, maxHeight: 760);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SnapFitColors.backgroundOf(context),
    constraints: const BoxConstraints(maxWidth: 920),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
    builder: builder,
  );
}

Future<PointShopPurchaseAction?> showPointShopPurchaseSheet(
  BuildContext context, {
  required PointShopAccess access,
  required String title,
}) => _showPointShopDialog<PointShopPurchaseAction>(
  context: context,
  builder: (_) => PointShopPurchaseSheet(access: access, title: title),
);

class PointShopPurchaseSheet extends StatelessWidget {
  const PointShopPurchaseSheet({
    super.key,
    required this.access,
    required this.title,
    this.purchase,
  });
  final PointShopAccess access;
  final String title;
  final PointShopPurchase? purchase;

  @override
  Widget build(BuildContext context) {
    final ink = ExperienceFormStyle.ink(context);
    final line = ExperienceFormStyle.line(context);
    final price = access.pointPrice ?? 0;
    final insufficient = purchase == null && access.remainingBalance < price;
    final template = access.productKey.startsWith('template:');
    final complete = purchase != null;
    final landscape = kIsWeb ||
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final artwork = PointShopArtwork(
      productKey: access.productKey,
      showBookMaterial: !kIsWeb,
    );
    TextStyle text(double size, {bool bold = false, bool secondary = false}) =>
        ExperienceFormStyle.text(
          context,
          size,
          weight: bold ? FontWeight.w600 : FontWeight.w400,
          secondary: secondary,
        );
    final product = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            key: const ValueKey('shop-purchase-artwork'),
            decoration: BoxDecoration(
              gradient: template && !kIsWeb ? AlbumStageStyle.gradient(context) : null,
              color: kIsWeb ? WebPalette.of(context).canvas : template
                  ? null
                  : MaterialOriginalPreview.backgroundFor(access.productKey),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: template
                  ? artwork
                  : MaterialOriginalPreview(
                      productKey: access.productKey,
                      child: artwork,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          access.title ?? title,
          maxLines: landscape ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: text(16, bold: true),
        ),
        if (!landscape) ...[
          const SizedBox(height: 2),
          Text(template ? '앨범 템플릿' : '꾸밈 소재', style: text(12, secondary: true)),
        ],
      ],
    );
    final amounts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AmountRow(
          label: complete ? '사용한 포인트' : '구매 가격',
          value: '${complete ? purchase!.chargedPoints : price}P',
          prominent: true,
        ),
        const SizedBox(height: 14),
        _AmountRow(
          label: complete ? '남은 포인트' : '보유 포인트',
          value:
              '${complete ? purchase!.remainingBalance : access.remainingBalance}P',
        ),
        if (!complete) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: line),
          const SizedBox(height: 14),
          _AmountRow(
            label: insufficient ? '부족한 포인트' : '구매 후 잔액',
            value:
                '${insufficient ? price - access.remainingBalance : access.remainingBalance - price}P',
            highlighted: true,
          ),
        ],
      ],
    );
    final usage = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        amounts,
        const SizedBox(height: 18),
        Divider(height: 1, color: line),
        const SizedBox(height: 14),
        Text('사용 범위', style: text(13, bold: true)),
        const SizedBox(height: 5),
        Text(
          template
              ? '템플릿 디자인을 이 계정에서 계속 사용할 수 있어요. 포함된 소재를 다른 앨범에 개별 사용하려면 소재별 보유 권한이 필요해요.'
              : '이 계정의 앨범에서 계속 사용할 수 있어요. 미리보기 사진과 예시 배치는 포함되지 않아요.',
          style: text(12, secondary: true),
        ),
        if (insufficient) ...[
          const SizedBox(height: 10),
          Text(
            '충전 후 이 상품으로 돌아와 가격을 다시 확인해요.',
            style: text(12, secondary: true),
          ),
        ],
      ],
    );
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, box) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(context).height * .90).clamp(
              0.0,
              box.maxHeight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, kIsWeb ? 18 : 4, 8, kIsWeb ? 16 : 4),
                child: Row(
                  children: [
                    if (complete) ...[
                      Icon(
                        Icons.check_circle_outline,
                        size: 22,
                        color: ExperienceFormStyle.selectionInk(context),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        complete
                            ? '구매 완료'
                            : insufficient
                            ? '포인트가 부족해요'
                            : '포인트로 구매',
                        style: text(18, bold: true),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 22, color: ink),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: landscape && box.maxWidth >= 520
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Row(
                          children: [
                            Expanded(flex: 5, child: product),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 6,
                              child: SingleChildScrollView(
                                key: const ValueKey(
                                  'shop-purchase-information',
                                ),
                                child: usage,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        key: const ValueKey('shop-purchase-information'),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 240, child: product),
                            const SizedBox(height: 20),
                            usage,
                          ],
                        ),
                      ),
              ),
              Divider(height: 1, color: line),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        complete ? '나중에' : '취소',
                        style: text(14, secondary: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('shop-purchase-action'),
                        style: kIsWeb
                            ? ExperienceFormStyle.primary(context).copyWith(
                                backgroundColor: WidgetStatePropertyAll(WebPalette.of(context).brand),
                                foregroundColor: WidgetStatePropertyAll(WebPalette.of(context).onBrand),
                              )
                            : ExperienceFormStyle.primary(context),
                        onPressed: () => Navigator.pop(
                          context,
                          complete
                              ? true
                              : insufficient
                              ? PointShopPurchaseAction.topUp
                              : PointShopPurchaseAction.buy,
                        ),
                        child: Text(
                          complete
                              ? template
                                    ? '템플릿 사용하기'
                                    : '소재 사용하기'
                              : insufficient
                              ? '포인트 충전'
                              : '${price}P로 구매',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.prominent = false,
    this.highlighted = false,
  });
  final String label, value;
  final bool prominent, highlighted;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ExperienceFormStyle.text(
      context,
      13,
      secondary: !prominent,
    );
    final valueStyle = ExperienceFormStyle.text(
      context,
      prominent ? 22 : 14,
      weight: prominent ? FontWeight.w700 : FontWeight.w600,
      color: highlighted ? ExperienceFormStyle.selectionInk(context) : null,
    );
    return Semantics(
      label: '$label $value',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            double width(String text, TextStyle style) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final result = painter.width;
              painter.dispose();
              return result;
            }

            final stacked =
                width(label, labelStyle) + width(value, valueStyle) + 12 >
                box.maxWidth;
            final amount = Text(value, maxLines: 1, style: valueStyle);
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(label, style: labelStyle),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(fit: BoxFit.scaleDown, child: amount),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text(label, style: labelStyle)),
                      const SizedBox(width: 12),
                      amount,
                    ],
                  );
          },
        ),
      ),
    );
  }
}

Future<bool> showPointShopPurchaseReceipt(
  BuildContext context, {
  required PointShopAccess access,
  required PointShopPurchase purchase,
  required String title,
}) async =>
    await _showPointShopDialog<bool>(
      context: context,
      builder: (_) => PointShopPurchaseSheet(
        access: access,
        title: title,
        purchase: purchase,
      ),
    ) ??
    false;
