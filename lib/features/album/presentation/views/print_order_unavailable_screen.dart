import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../profile/presentation/views/order_history_screen.dart';
import '../widgets/print_fulfillment_notice.dart';
import 'print_order_preview_screen.dart';

class PrintOrderUnavailableScreen extends StatelessWidget {
  const PrintOrderUnavailableScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.pageCount,
  });
  final String albumTitle;
  final int albumId;
  final int pageCount;

  @override
  Widget build(BuildContext context) => kIsWeb ? _webUnavailable(context) : Scaffold(
    backgroundColor: SnapFitColors.backgroundOf(context),
    appBar: const ExperienceHeader(title: '인쇄 주문', themeAware: true),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.fromLTRB(
            ((constraints.maxWidth - 600) / 2).clamp(20, double.infinity),
            28,
            ((constraints.maxWidth - 600) / 2).clamp(20, double.infinity),
            28,
          ),
          children: [
            Text(
              '인화 주문 결제 준비 중',
              style: ExperienceFormStyle.text(
                context,
                22,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '현재는 인화 주문을 접수할 수 없습니다.\n완성한 앨범은 보관하고 계속 수정할 수 있습니다.',
              style: ExperienceFormStyle.text(context, 14, secondary: true),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: ExperienceFormStyle.line(context)),
                  bottom: BorderSide(color: ExperienceFormStyle.line(context)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 24,
                    color: ExperienceFormStyle.ink(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          albumTitle,
                          style: ExperienceFormStyle.text(
                            context,
                            16,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$pageCount페이지',
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            secondary: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '주문 전 미리 확인해요',
              style: ExperienceFormStyle.text(
                context,
                14,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '인쇄 미리보기와 PDF 만들기는 이용할 수 있어요.',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: ExperienceFormStyle.primary(context),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PrintOrderPreviewScreen(
                    albumId: albumId,
                    albumTitle: albumTitle,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 20),
              label: const Text('인쇄 미리보기 · PDF 만들기'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: null,
              child: const Text('결제 준비 중'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: ExperienceFormStyle.ink(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('앨범으로 돌아가기'),
            ),
            TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
              ),
              child: const Text('기존 주문 내역 보기'),
            ),
            const SizedBox(height: 24),
            const PrintFulfillmentNotice(),
          ],
        ),
      ),
    ),
  );

  Widget _webUnavailable(BuildContext context) => SnapFitWebShell(
    title: '인쇄 주문',
    section: WebSection.orders,
    showNavigation: false,
    actions: [TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('앨범으로'))],
    child: ListView(children: [
      const WebPageHeading(
        eyebrow: '앨범  /  인쇄 주문',
        title: '인쇄 주문을 준비하고 있습니다',
        description: '완성한 앨범은 그대로 보관됩니다. 지금은 인쇄 배치를 미리 확인하고 검수용 PDF를 만들 수 있습니다.',
      ),
      const SizedBox(height: 28),
      LayoutBuilder(builder: (context, bounds) {
        final album = WebSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(Icons.menu_book_outlined, color: WebPalette.of(context).brandInk, size: 32),
          const SizedBox(height: 20),
          Text(albumTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
          const SizedBox(height: 8),
          Text('$pageCount페이지', style: TextStyle(fontSize: 14, color: WebPalette.of(context).muted)),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => PrintOrderPreviewScreen(albumId: albumId, albumTitle: albumTitle))),
            icon: const Icon(Icons.fact_check_outlined, size: 19),
            label: const Text('인쇄 미리보기 · PDF 만들기'),
          ),
          const SizedBox(height: 12),
          const OutlinedButton(onPressed: null, child: Text('결제 준비 중')),
          const SizedBox(height: 12),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('앨범 계속 편집하기')),
        ]));
        final information = WebSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('주문 전에 확인하세요', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('현재는 실제 결제와 제작 요청을 접수하지 않습니다. 인쇄 미리보기나 PDF 저장만으로 주문이 만들어지지는 않습니다.', style: TextStyle(fontSize: 14, height: 1.7, color: WebPalette.of(context).muted)),
          const SizedBox(height: 24),
          Divider(color: WebPalette.of(context).line),
          const SizedBox(height: 20),
          const PrintFulfillmentNotice(),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('기존 주문 내역 보기'),
          )),
        ]));
        if (bounds.maxWidth < 900) return Column(children: [album, const SizedBox(height: 20), information]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: album), const SizedBox(width: 24), Expanded(flex: 6, child: information)]);
      }),
    ]),
  );
}
