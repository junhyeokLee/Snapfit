import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../profile/data/order_repository.dart';
import '../../printing/album_print_exporter.dart';
import '../../printing/print_album_document.dart';
import '../widgets/print_fulfillment_notice.dart';

final printPreviewExporterProvider = Provider<AlbumPrintExporter>(
  (ref) => AlbumPrintExporter(),
);

/// Read-only production preview. Physical-goods checkout remains unavailable.
class PrintOrderPreviewScreen extends ConsumerStatefulWidget {
  const PrintOrderPreviewScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
  });
  final int albumId;
  final String albumTitle;

  @override
  ConsumerState<PrintOrderPreviewScreen> createState() =>
      _PrintOrderPreviewScreenState();
}

class _PrintOrderPreviewScreenState
    extends ConsumerState<PrintOrderPreviewScreen> {
  OrderQuoteResult? _quote;
  PrintAlbumDocument? _document;
  Map<String, dynamic>? _snapshot;
  PrintVendorSpec? _spec;
  PrintProduct? _product;
  Map<String, dynamic>? _report;
  AlbumPrintExport? _export;
  bool _loading = true;
  bool _busy = false;
  bool _checkedLayout = false;
  String? _error;
  String? _progress;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _checkedLayout = false;
      _report = null;
      _export = null;
      _quote = null;
      _document = null;
      _snapshot = null;
      _spec = null;
      _product = null;
    });
    try {
      final results = await Future.wait<Object>([
        ref
            .read(orderRepositoryProvider)
            .fetchOrderQuote(albumId: widget.albumId),
        ref
            .read(orderRepositoryProvider)
            .fetchPrintPreviewSnapshot(albumId: widget.albumId),
      ]);
      final quote = results[0] as OrderQuoteResult;
      final snapshot = results[1] as Map<String, dynamic>;
      final document = PrintAlbumDocument.fromSnapshot(snapshot);
      if (quote.pageCount > 80 || document.interiors.length > 80) {
        throw const PrintPreflightException(
          'print_paid_page_count_exceeded',
          [],
        );
      }
      if (quote.pageCount < 20 ||
          quote.pageCount.isOdd ||
          quote.pageCount < document.interiors.length ||
          quote.sourcePageCount != document.interiors.length) {
        throw const FormatException('print_page_count_mismatch');
      }
      final product = document.productForNewPreview;
      if ((quote.productCode.isNotEmpty && quote.productCode != product.id) ||
          (quote.printProduct.isNotEmpty &&
              PrintProduct.fromJson(quote.printProduct).id != product.id)) {
        throw const FormatException('print_product_spec_mismatch');
      }
      final spec = quote.specMissing
          ? null
          : PrintVendorSpec.fromJson(quote.printSpec);
      if (spec != null) document.validateSpec(spec, newPreview: true);
      if (spec != null && spec.pageCount != quote.pageCount)
        throw const FormatException('print_page_count_mismatch');
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _document = document;
        _snapshot = snapshot;
        _spec = spec;
        _product = product;
        _page = 0;
        _progress = '사진 원본과 인쇄 크기를 확인하는 중';
      });
      if (spec == null) return;
      final report = await ref
          .read(printPreviewExporterProvider)
          .verify(
            snapshot: snapshot,
            spec: spec,
            onProgress: (done, total) {
              if (mounted)
                setState(
                  () => _progress = '사진 원본과 인쇄 크기를 확인하는 중 $done / $total',
                );
            },
          );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) setState(() => _error = printPreviewErrorMessage(e));
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _progress = null;
        });
    }
  }

  Future<void> _generate() async {
    if (_busy || _spec == null || _report == null || !_checkedLayout) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final output = await ref
          .read(printPreviewExporterProvider)
          .generate(
            snapshot: _snapshot!,
            spec: _spec!,
            onProgress: (done, total) {
              if (mounted) setState(() => _progress = 'PDF 준비중 $done / $total');
            },
          );
      if (mounted) setState(() => _export = output);
    } catch (e) {
      if (mounted) setState(() => _error = printPreviewErrorMessage(e));
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = null;
        });
    }
  }

  Future<void> _share(Uint8List bytes, String name) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [name],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'PDF 저장 창을 열지 못했습니다. 다시 시도해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final document = _document;
    final previewRatio = _page == 0 && _spec != null
        ? _spec!.front.size.aspectRatio
        : _product?.aspectRatio ?? 1;
    final warnings =
        (_report?['imageResolution'] as List?)
            ?.whereType<Map>()
            .where((item) => (item['effectivePpi'] as num? ?? 300) < 300)
            .length ??
        0;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          title: const Text('책으로 만들면'),
          actions: [
            IconButton(
              onPressed: _loading || _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: '최신 앨범으로 다시 확인',
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.albumTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_product != null) Text('${_product!.label} · 1권'),
              if (_loading || _busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_progress ?? '앨범과 제작 금액을 불러오는 중'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
                if (!_loading && !_busy)
                  OutlinedButton(onPressed: _load, child: const Text('다시 확인')),
              ],
              if (quote != null) ...[
                const SizedBox(height: 20),
                Text(
                  '${_won(quote.amount)}원 예상',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  quote.shippingIncluded
                      ? '기본 배송비 포함 · 결제 서비스 준비 전 참고 금액입니다.'
                      : '결제 서비스 준비 전 참고 금액입니다.',
                ),
                if (quote.priceIsEstimate)
                  const Text('이 크기의 제작비는 추정치이며 업체 주문창의 실제 청구금액 확인 후 확정됩니다.'),
                if (quote.specMissing) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '표지 제작 도면을 확인하는 중입니다. 앨범 배치와 예상 금액을 확인할 수 있으며, 검수용 PDF는 도면 확인 후 만들 수 있습니다.',
                  ),
                ],
                Text('내지 ${quote.pageCount}페이지 · 앞표지와 뒤표지 별도'),
                Text(
                  '작성한 내지 ${quote.sourcePageCount}페이지 + 뒤에 추가되는 빈 페이지 ${quote.addedBlankPageCount}페이지',
                ),
                if (quote.extraPageCount > 0)
                  Text(
                    '기본 ${quote.basePages}페이지 ${_won(quote.basePrice)}원 + 추가 ${quote.extraPageCount}페이지 ${_won(quote.extraPageCount * quote.extraPagePrice)}원',
                  ),
              ],
              if (document != null && quote != null) ...[
                const SizedBox(height: 24),
                Text(
                  '${_product!.sizeLabel} 책에서의 배치',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  '선택한 책 크기 안에 전체 디자인을 맞춥니다. 표지의 장식용 책등을 제외하면서 여백이 생길 수 있습니다. 뒷표지는 앞표지의 배경색으로 만듭니다.',
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: previewRatio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                    ),
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final pages = [document.cover, ...document.interiors];
                        final page = _page < pages.length ? pages[_page] : null;
                        return page == null
                            ? const ColoredBox(
                                color: Colors.white,
                                child: Center(child: Text('빈 페이지')),
                              )
                            : PrintPageLayoutPreview(
                                page: page,
                                size: bounds.maxWidth,
                                aspectRatio: previewRatio,
                              );
                      },
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _page > 0
                          ? () => setState(() {
                              _page--;
                              _checkedLayout = false;
                            })
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        _page == 0
                            ? '앞표지'
                            : '내지 $_page / ${quote.pageCount}${_page > document.interiors.length ? ' · 추가 빈 페이지' : ''}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: _page < quote.pageCount
                          ? () => setState(() {
                              _page++;
                              _checkedLayout = false;
                            })
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const Text(
                  '사진·문구의 위치를 확인하는 미리보기입니다. 인쇄 색상과 재단 위치는 실물 샘플로 확인합니다.',
                ),
              ],
              if (_report != null) ...[
                const SizedBox(height: 16),
                const Text('사진 원본과 글꼴 확인을 마쳤습니다.'),
                if (warnings > 0)
                  Text('$warnings개 사진은 권장 해상도보다 낮아 인쇄 시 선명도가 낮아질 수 있습니다.'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _checkedLayout,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _checkedLayout = value == true),
                  title: const Text('선택한 책 크기의 배치, 여백과 추가 빈 페이지를 확인했습니다.'),
                ),
                FilledButton.icon(
                  onPressed: _busy || !_checkedLayout ? null : _generate,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('표지·내지 검수용 PDF 만들기'),
                ),
                const Text('PDF는 업체 작업 가이드와 대조하고 실물 샘플을 확인한 뒤 제작에 사용합니다.'),
              ],
              if (_export != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _share(
                    _export!.coverPdf,
                    'snapfit-${widget.albumId}-cover-review.pdf',
                  ),
                  child: const Text('표지 PDF 보기·저장'),
                ),
                OutlinedButton(
                  onPressed: () => _share(
                    _export!.interiorPdf,
                    'snapfit-${widget.albumId}-interior-review.pdf',
                  ),
                  child: const Text('내지 PDF 보기·저장'),
                ),
              ],
              const SizedBox(height: 24),
              const PrintFulfillmentNotice(),
              const SizedBox(height: 24),
              const FilledButton(onPressed: null, child: Text('인화 주문 결제 준비 중')),
              const SizedBox(height: 8),
              const Text(
                '현재 주문과 결제는 접수하지 않습니다. 앨범은 보관하고 계속 수정할 수 있습니다.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrintPageLayoutPreview extends StatelessWidget {
  const PrintPageLayoutPreview({
    super.key,
    required this.page,
    required this.size,
    this.aspectRatio = 1,
  });
  final PrintAlbumPage page;
  final double size;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: page.backgroundColor,
      child: SizedBox(
        width: size,
        height: size / aspectRatio,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox.fromSize(
            size: page.canvasSize,
            child: PrintAlbumPageCanvas(page: page),
          ),
        ),
      ),
    );
  }
}

String printPreviewErrorMessage(Object error) {
  final message = error is PostgrestException
      ? error.message
      : error is FormatException
      ? error.message.toString()
      : '';
  if (message.contains('hardcover_template_required')) {
    return '하드커버 표지 제작 도면을 확인하는 중입니다. 확인 후 검수용 PDF를 만들 수 있습니다.';
  }
  if (message.contains('unsupported_print_product')) {
    return '이 앨범의 세로형 또는 비규격 크기는 현재 책 제작을 지원하지 않습니다. 앨범은 원래 크기로 보관됩니다.';
  }
  if (message.contains('print_product')) {
    return '저장된 앨범 크기와 제작 규격이 일치하지 않습니다. 앨범을 다시 저장하고 확인해주세요.';
  }
  if (error is PostgrestException &&
      error.message.contains('invalid_page_count')) {
    return '내지 페이지 수가 제작 규격을 초과했습니다. 80페이지 이하로 줄여주세요.';
  }
  if (error is PrintPreflightException) {
    return switch (error.code) {
      'print_original_load_failed' ||
      'print_original_missing' ||
      'print_text_image_missing' =>
        '사진 원본을 불러오지 못했습니다. 앨범에서 해당 사진을 다시 저장한 후 확인해주세요.',
      'print_image_memory_limit' =>
        '이 페이지의 사진 크기가 너무 큽니다. 사진 수를 줄이거나 이미지를 다시 저장해주세요.',
      'print_font_unavailable' => '사용한 글꼴을 인쇄 파일에 적용할 수 없습니다. 다른 글꼴로 변경해주세요.',
      'print_image_resolution_too_low' =>
        '사진 해상도가 인쇄하기에 너무 낮습니다. 원본 사진으로 바꾸거나 사진을 작게 배치해주세요.',
      'print_paid_page_count_exceeded' =>
        '내지 페이지 수가 제작 규격을 초과했습니다. 80페이지 이하로 줄여주세요.',
      _ => '이 앨범은 아직 인쇄 파일로 만들 수 없습니다. 앨범을 다시 저장한 후 확인해주세요.',
    };
  }
  if (error is FormatException)
    return '앨범 데이터 또는 인쇄 규격을 확인하지 못했습니다. 앨범을 다시 저장하고 재시도해주세요.';
  return '앨범과 제작 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
}

String _won(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);
