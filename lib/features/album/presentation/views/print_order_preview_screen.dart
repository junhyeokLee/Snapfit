import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../profile/presentation/widgets/customer_web_page.dart';
import '../../../profile/data/order_repository.dart';
import '../../../profile/data/print_dev_checkout.dart';
import '../../../profile/data/customer_print_test_checkout.dart';
import '../../../profile/presentation/views/order_history_screen.dart';
import '../../../profile/domain/print_checkout.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../printing/album_print_exporter.dart';
import '../../printing/print_album_document.dart';
import '../utils/print_photo_issue.dart';
import '../utils/open_print_photo_editor.dart';
import '../widgets/print_fulfillment_notice.dart';
import 'print_order_checkout_screen.dart';
import 'print_dev_checkout_screen.dart';

final printPreviewExporterProvider = Provider<AlbumPrintExporter>(
  (ref) => AlbumPrintExporter(loadOnlyUsedFonts: true),
);

/// Reviews the saved album before delivery and server checkout readiness.
class PrintOrderPreviewScreen extends ConsumerStatefulWidget {
  const PrintOrderPreviewScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    this.onEditPhotoIssue,
  });
  final int albumId;
  final String albumTitle;
  final Future<bool> Function(PrintPhotoEditTarget target)? onEditPhotoIssue;

  @override
  ConsumerState<PrintOrderPreviewScreen> createState() =>
      _PrintOrderPreviewScreenState();
}

class _PrintOrderPreviewScreenState
    extends ConsumerState<PrintOrderPreviewScreen>
    with WidgetsBindingObserver {
  OrderQuoteResult? _quote;
  PrintAlbumDocument? _document;
  Map<String, dynamic>? _snapshot;
  PrintVendorSpec? _spec;
  PrintProduct? _product;
  Map<String, dynamic>? _report;
  List<PrintPhotoIssue> _photoIssues = const [];
  final GlobalKey _previewStageKey = GlobalKey();
  AlbumPrintExport? _export;
  bool _loading = true;
  bool _busy = false;
  bool _openingCheckout = false;
  bool _openingPhotoEditor = false;
  bool _checkedLayout = false;
  bool _quoteIsFinal = false;
  bool _refreshingPrice = false;
  String? _error;
  String? _priceRefreshError;
  String? _priceUpdateNotice;
  String? _progress;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    if (kIsWeb) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb &&
        state == AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_refreshDisplayedQuote());
    }
  }

  // A price update does not change the reviewed artwork or require fetching
  // the original photos and fonts again. Changed geometry needs a new review.
  Future<void> _refreshDisplayedQuote() async {
    final previous = _quote;
    final snapshot = _snapshot;
    if (!kIsWeb ||
        _loading ||
        _busy ||
        _openingCheckout ||
        _openingPhotoEditor ||
        _refreshingPrice ||
        previous == null ||
        snapshot == null) {
      return;
    }
    setState(() => _refreshingPrice = true);
    try {
      final readiness = await ref
          .read(orderRepositoryProvider)
          .fetchPrintCheckoutReadiness(albumId: widget.albumId);
      if (!mounted ||
          !identical(_quote, previous) ||
          !identical(_snapshot, snapshot)) {
        return;
      }
      final quote = readiness.quote;
      final reviewChanged =
          readiness.reviewedRevision != null &&
              readiness.reviewedRevision != printCheckoutRevision(snapshot) ||
          quote.productCode != previous.productCode ||
          quote.pageCount != previous.pageCount ||
          quote.sourcePageCount != previous.sourcePageCount ||
          quote.specMissing != previous.specMissing ||
          printSpecRevision(quote.printSpec) !=
              printSpecRevision(previous.printSpec) ||
          readiness.reviewedSpecRevision != null &&
              readiness.reviewedSpecRevision !=
                  printSpecRevision(quote.printSpec);
      setState(() {
        if (reviewChanged) {
          _checkedLayout = false;
          _report = null;
          _photoIssues = const [];
          _export = null;
          _priceRefreshError = '앨범 내용이나 제작 규격이 바뀌었어요. 최신 앨범으로 다시 확인해주세요.';
          _priceUpdateNotice = null;
          return;
        }
        final priceChanged =
            quote.amount != previous.amount ||
            quote.pricePolicyVersion != previous.pricePolicyVersion ||
            quote.shippingIncluded != previous.shippingIncluded ||
            quote.retailPriceStatus != previous.retailPriceStatus;
        _quote = quote;
        _quoteIsFinal = quote.hasFinalRetailPrice;
        _priceRefreshError = null;
        if (priceChanged) {
          _priceUpdateNotice = '판매가 안내가 갱신되었습니다. 현재 금액을 확인해주세요.';
        }
      });
    } catch (_) {
      if (mounted &&
          identical(_quote, previous) &&
          identical(_snapshot, snapshot)) {
        setState(() {
          _priceRefreshError = '최신 판매가를 확인하지 못했어요. 다시 확인한 뒤 주문 내용을 이어가주세요.';
          _priceUpdateNotice = null;
        });
      }
    } finally {
      if (mounted) setState(() => _refreshingPrice = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _priceRefreshError = null;
      _priceUpdateNotice = null;
      _checkedLayout = false;
      _quoteIsFinal = false;
      _report = null;
      _photoIssues = const [];
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
            .fetchPrintCheckoutReadiness(albumId: widget.albumId),
        ref
            .read(orderRepositoryProvider)
            .fetchPrintPreviewSnapshot(albumId: widget.albumId),
      ]);
      final readiness = results[0] as PrintCheckoutReadiness;
      final quote = readiness.quote;
      final snapshot = results[1] as Map<String, dynamic>;
      if (readiness.reviewedRevision != null &&
              readiness.reviewedRevision != printCheckoutRevision(snapshot) ||
          readiness.reviewedSpecRevision != null &&
              readiness.reviewedSpecRevision !=
                  printSpecRevision(quote.printSpec)) {
        throw const FormatException('print_review_changed');
      }
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
        _quoteIsFinal = quote.hasFinalRetailPrice;
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
      if (mounted) {
        setState(() {
          _report = report;
          _photoIssues = printPhotoIssues(
            document: document,
            reviewedRevision: printCheckoutRevision(snapshot),
            recommendedPpi: spec.dpi,
            report: report,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = printPreviewErrorMessage(e);
          _setFailurePhotoIssue(e);
        });
      }
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _progress = null;
        });
    }
  }

  void _setFailurePhotoIssue(Object error) {
    final document = _document;
    final snapshot = _snapshot;
    final spec = _spec;
    if (error is! PrintPreflightException ||
        document == null ||
        snapshot == null ||
        spec == null)
      return;
    _photoIssues = printPhotoIssues(
      document: document,
      reviewedRevision: printCheckoutRevision(snapshot),
      recommendedPpi: spec.dpi,
      report: _report,
      failure: error,
    );
  }

  Future<void> _showPhotoIssue(PrintPhotoIssue issue) async {
    if (_loading || _busy || _openingCheckout || _openingPhotoEditor) return;
    setState(() {
      _page = issue.target.pageIndex;
      _checkedLayout = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    final stageContext = _previewStageKey.currentContext;
    if (mounted && stageContext != null) {
      await Scrollable.ensureVisible(stageContext, alignment: .15);
    }
  }

  Future<void> _editPhotoIssue(PrintPhotoIssue issue) async {
    final edit = widget.onEditPhotoIssue;
    if (_loading ||
        _busy ||
        _openingCheckout ||
        _openingPhotoEditor ||
        _refreshingPrice ||
        !_photoIssues.contains(issue))
      return;
    final owner = ref.read(visibleOrderOwnerProvider);
    setState(() {
      _openingPhotoEditor = true;
      _checkedLayout = false;
      _export = null;
    });
    try {
      await (edit != null
          ? edit(issue.target)
          : openPrintPhotoEditor(
              context,
              ref,
              albumId: widget.albumId,
              target: issue.target,
            ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 편집을 열지 못했어요. 앨범에서 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted &&
          owner != null &&
          ref.read(visibleOrderOwnerProvider) == owner) {
        await _load();
      }
      if (mounted) setState(() => _openingPhotoEditor = false);
    }
  }

  Future<void> _generate() async {
    if (_busy ||
        _openingPhotoEditor ||
        _spec == null ||
        _report == null ||
        !_checkedLayout)
      return;
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
      if (mounted) {
        setState(() {
          _error = printPreviewErrorMessage(e);
          _setFailurePhotoIssue(e);
        });
      }
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = null;
        });
    }
  }

  Future<void> _continueToCheckout() async {
    if (_loading ||
        _busy ||
        _openingCheckout ||
        _openingPhotoEditor ||
        _refreshingPrice ||
        !_checkedLayout ||
        _error != null ||
        _priceRefreshError != null ||
        _report == null ||
        _spec == null ||
        _quote == null ||
        _snapshot == null) {
      return;
    }
    setState(() => _openingCheckout = true);
    try {
      final revision = printCheckoutRevision(_snapshot!);
      CustomerPrintTestCapability? test;
      if (ref.read(printDevAdminAccessProvider) &&
          _product?.id == 'REDP_300_HARD' &&
          _document?.interiors.length == 80) {
        test = await ref
            .read(customerPrintTestCheckoutServiceProvider)
            .capability(albumId: widget.albumId, reviewedRevision: revision);
      }
      if (!mounted) return;
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => PrintOrderCheckoutScreen(
            albumId: widget.albumId,
            albumTitle: widget.albumTitle,
            initialQuote: _quote!,
            reviewedRevision: revision,
            testMode: test != null,
            onOpenTestOrder: (runId) => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => OrderHistoryScreen(initialTestRunId: runId),
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (result == 'review_again') {
        await _load();
      } else if (result == 'edit_album') {
        Navigator.pop(context, 'edit_album');
      } else if (kIsWeb) {
        setState(() => _openingCheckout = false);
        await _refreshDisplayedQuote();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '주문 화면을 준비하지 못했어요. 결제는 시작하지 않았습니다. 다시 확인해주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _openingCheckout = false);
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

  Future<void> _openDevelopmentCheckout() async {
    if (!ref.read(printDevAdminAccessProvider) ||
        _loading ||
        _busy ||
        !_checkedLayout ||
        _snapshot == null ||
        _report == null ||
        _product?.id != 'REDP_300_HARD' ||
        _document?.interiors.length != 80)
      return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PrintDevCheckoutScreen(
          albumId: widget.albumId,
          albumTitle: widget.albumTitle,
          reviewedRevision: printCheckoutRevision(_snapshot!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final document = _document;
    final previewRatio = _page == 0 && _spec != null
        ? _spec!.front.size.aspectRatio
        : _product?.aspectRatio ?? 1;
    return PopScope(
      canPop: !_busy && !_openingPhotoEditor,
      child: kIsWeb
          ? _webPreview(document, quote, previewRatio)
          : Scaffold(
              backgroundColor: SnapFitColors.backgroundOf(context),
              appBar: ExperienceHeader(
                title: '인쇄 미리보기',
                themeAware: true,
                actions: [
                  IconButton(
                    onPressed: _loading || _busy || _openingPhotoEditor
                        ? null
                        : _load,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: '최신 앨범으로 다시 확인',
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final hasPreview = document != null && quote != null;
                    final wide =
                        bounds.maxWidth >= 520 &&
                        bounds.maxWidth > bounds.maxHeight;
                    if (wide && hasPreview) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                12,
                                20,
                                12,
                              ),
                              child: _previewStage(
                                document,
                                quote,
                                previewRatio,
                              ),
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            color: ExperienceFormStyle.line(context),
                          ),
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              key: const ValueKey(
                                'print-preview-details-scroll',
                              ),
                              padding: const EdgeInsets.all(24),
                              child: _details(context),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView(
                      key: const ValueKey('print-preview-details-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      children: [
                        if (hasPreview) ...[
                          Text(
                            widget.albumTitle,
                            style: ExperienceFormStyle.text(
                              context,
                              22,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: math
                                .min(380, bounds.maxHeight * .62)
                                .clamp(220, 380)
                                .toDouble(),
                            child: _previewStage(document, quote, previewRatio),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _details(context, showTitle: !hasPreview),
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _webPreview(
    PrintAlbumDocument? document,
    OrderQuoteResult? quote,
    double ratio,
  ) {
    final hasPreview = document != null && quote != null;
    return SnapFitWebShell(
      title: '앨범 주문',
      section: WebSection.orders,
      showNavigation: false,
      actions: [
        TextButton.icon(
          onPressed: _busy || _openingPhotoEditor
              ? null
              : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('앨범으로'),
        ),
        IconButton(
          onPressed:
              _loading || _busy || _refreshingPrice || _openingPhotoEditor
              ? null
              : _load,
          tooltip: '최신 앨범으로 다시 확인',
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, viewport) {
          final stageHeight = (viewport.maxHeight - 130)
              .clamp(360.0, 720.0)
              .toDouble();
          return ListView(
            key: const ValueKey('web-print-preview-scroll'),
            children: [
              const WebPageHeading(
                title: '인쇄 미리보기',
                description: '사진과 글의 배치, 여백과 페이지 구성을 확인하세요.',
              ),
              const SizedBox(height: 24),
              CustomerWebColumns(
                breakpoint: 980,
                summaryWidth: 360,
                primary: SizedBox(
                  height: stageHeight,
                  child: WebSurface(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              widget.albumTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_product != null)
                              Text(
                                _product!.sizeLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: WebPalette.of(context).muted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: WebPalette.of(context).canvas,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: hasPreview
                                  ? _previewStage(document, quote, ratio)
                                  : Center(
                                      child: _loading
                                          ? const CircularProgressIndicator()
                                          : const Text('앨범 정보를 다시 확인해주세요.'),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                secondary: WebSurface(
                  child: _details(context, showTitle: false),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _previewStage(
    PrintAlbumDocument document,
    OrderQuoteResult quote,
    double ratio,
  ) {
    final pages = [document.cover, ...document.interiors];
    final page = _page < pages.length ? pages[_page] : null;
    return Column(
      key: _previewStageKey,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final width = math
                  .min(bounds.maxWidth - 24, (bounds.maxHeight - 16) * ratio)
                  .clamp(1, double.infinity)
                  .toDouble();
              return Center(
                child: SizedBox(
                  key: const ValueKey('print-preview-page'),
                  width: width,
                  height: width / ratio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .1),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: page == null
                        ? const ColoredBox(
                            color: Colors.white,
                            child: Center(
                              child: Text(
                                '빈 페이지',
                                style: TextStyle(
                                  color: kIsWeb
                                      ? SnapFitColors.deepCharcoal
                                      : null,
                                ),
                              ),
                            ),
                          )
                        : PrintPageLayoutPreview(
                            page: page,
                            size: width,
                            aspectRatio: ratio,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: '이전 페이지',
              onPressed: !_busy && _page > 0
                  ? () => setState(() {
                      _page--;
                      _checkedLayout = false;
                    })
                  : null,
              icon: const Icon(Icons.chevron_left, size: 24),
            ),
            Expanded(
              child: Text(
                _page == 0
                    ? '앞표지'
                    : '내지 $_page / ${quote.pageCount}${_page > document.interiors.length ? ' · 추가 빈 페이지' : ''}',
                textAlign: TextAlign.center,
                style: ExperienceFormStyle.text(context, 13),
              ),
            ),
            IconButton(
              tooltip: '다음 페이지',
              onPressed: !_busy && _page < quote.pageCount
                  ? () => setState(() {
                      _page++;
                      _checkedLayout = false;
                    })
                  : null,
              icon: const Icon(Icons.chevron_right, size: 24),
            ),
          ],
        ),
      ],
    );
  }

  Widget _details(BuildContext context, {bool showTitle = true}) {
    final quote = _quote;
    Widget note(String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        value,
        style: ExperienceFormStyle.text(context, 13, secondary: true),
      ),
    );
    Widget heading(String value) => Text(
      value,
      style: ExperienceFormStyle.text(context, 17, weight: FontWeight.w600),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            widget.albumTitle,
            style: ExperienceFormStyle.text(
              context,
              22,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_product != null)
          Text(
            '${_product!.label} · 1권',
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
        if (_loading || _busy || _refreshingPrice) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          note(
            _refreshingPrice
                ? '최신 판매가를 확인하는 중'
                : _progress ?? '앨범과 제작 금액을 불러오는 중',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: ExperienceFormStyle.text(context, 14)),
          if (!_loading && !_busy && !_openingPhotoEditor)
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 확인'),
            ),
        ],
        if (_priceRefreshError != null) ...[
          const SizedBox(height: 16),
          Text(
            _priceRefreshError!,
            key: const ValueKey('print-preview-price-refresh-error'),
            style: ExperienceFormStyle.text(context, 14),
          ),
          if (!_loading && !_busy && !_refreshingPrice && !_openingPhotoEditor)
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('최신 앨범으로 다시 확인'),
            ),
        ],
        if (_priceUpdateNotice != null) note(_priceUpdateNotice!),
        if (_photoIssues.isNotEmpty) ...[
          const SizedBox(height: 20),
          heading('선명도를 확인할 사진'),
          note('원본 사진으로 바꾸거나 사진을 작게 배치하면 선명도를 높일 수 있어요.'),
          for (final issue in _photoIssues) _photoIssueCard(context, issue),
          if (_openingPhotoEditor) note('사진 편집 권한과 최신 앨범을 확인하고 있어요.'),
        ],
        if (quote != null) ...[
          const SizedBox(height: 20),
          if (kIsWeb) ...[
            Text(
              quote.hasPlannedRetailPrice && !_quoteIsFinal ? '예정 판매가' : '판매가',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            quote.hasPlannedRetailPrice && _priceRefreshError == null
                ? '${_won(quote.amount)}원${!kIsWeb && !_quoteIsFinal ? ' 예정' : ''}'
                : kIsWeb
                ? '가격 확인 필요'
                : '견적 확인 중',
            style: ExperienceFormStyle.text(
              context,
              26,
              weight: FontWeight.w700,
            ),
          ),
          if (quote.hasPlannedRetailPrice)
            note(quote.shippingIncluded ? '기본 배송비 포함' : '배송비는 최종 확인 시 안내합니다.'),
          note(
            quote.priceNotice.isNotEmpty
                ? quote.priceNotice
                : _quoteIsFinal
                ? '확인된 최종 판매가입니다. 배송지를 입력한 뒤 주문 내용을 확인해주세요.'
                : quote.hasPlannedRetailPrice
                ? '제작 견적을 반영한 예정 판매가입니다. 현재 주문·결제는 준비 중입니다.'
                : kIsWeb
                ? '이 규격·페이지 조합의 제작비를 아직 확인하지 못했습니다. 비용 확인 후 판매가를 안내합니다.'
                : '이 규격·페이지 조합의 제작 견적을 확인한 뒤 판매가를 안내합니다.',
          ),
          const SizedBox(height: 24),
          Divider(color: ExperienceFormStyle.line(context)),
          const SizedBox(height: 16),
          heading('제작 구성'),
          note('내지 ${quote.pageCount}페이지 · 앞표지와 뒤표지 별도'),
          note(
            '작성한 내지 ${quote.sourcePageCount}페이지 + 뒤에 추가되는 빈 페이지 ${quote.addedBlankPageCount}페이지',
          ),
          if (quote.hasPlannedRetailPrice && quote.extraPageCount > 0)
            note(
              '기본 ${quote.basePages}페이지 ${_won(quote.basePrice)}원 + 추가 ${quote.extraPageCount}페이지 ${_won(quote.extraPageCount * quote.extraPagePrice)}원',
            ),
          const SizedBox(height: 24),
          heading('${_product!.sizeLabel} 책에서의 배치'),
          note(
            '선택한 책 크기 안에 전체 디자인을 맞춥니다. 표지의 장식용 책등을 제외하면서 여백이 생길 수 있습니다. 뒷표지는 앞표지의 배경색으로 만듭니다.',
          ),
          note('사진·문구의 위치를 확인하는 미리보기입니다. 인쇄 색상과 재단 위치는 실물 샘플로 확인합니다.'),
          if (quote.specMissing)
            note(
              '표지 제작 도면을 확인하는 중입니다. 앨범 배치와 예상 금액을 확인할 수 있으며, 검수용 PDF는 도면 확인 후 만들 수 있습니다.',
            ),
        ],
        if (_report != null) ...[
          const SizedBox(height: 24),
          heading('인쇄 전 확인'),
          note('사진 원본과 글꼴 확인을 마쳤습니다.'),
          if (_photoIssues.isNotEmpty)
            note(
              '${_photoIssues.length}개 사진은 권장 해상도보다 낮아 인쇄 시 선명도가 낮아질 수 있습니다.',
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _checkedLayout,
            onChanged: _busy || _openingPhotoEditor
                ? null
                : (value) => setState(() => _checkedLayout = value == true),
            title: Text(
              '선택한 책 크기의 배치, 여백과 추가 빈 페이지를 확인했습니다.',
              style: ExperienceFormStyle.text(context, 13),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('print-continue-to-delivery'),
              onPressed:
                  _loading ||
                      _busy ||
                      _openingCheckout ||
                      _openingPhotoEditor ||
                      _refreshingPrice ||
                      !_checkedLayout ||
                      _error != null ||
                      _priceRefreshError != null
                  ? null
                  : _continueToCheckout,
              style: ExperienceFormStyle.primary(context),
              child: const Text('배송지 입력하기'),
            ),
          ),
          note('배송지와 최종 주문 내용을 확인합니다. 결제 가능 여부는 다음 화면에서 안내해요.'),
          if (ref.watch(printDevAdminAccessProvider) &&
              _product?.id == 'REDP_300_HARD' &&
              _document?.interiors.length == 80) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('print-admin-development-order'),
              onPressed:
                  _loading ||
                      _busy ||
                      _openingPhotoEditor ||
                      !_checkedLayout ||
                      _error != null
                  ? null
                  : _openDevelopmentCheckout,
              icon: const Icon(Icons.science_outlined),
              label: const Text('관리자 개발 주문 테스트'),
            ),
            note('포트원 TEST와 업체 개발 환경만 사용합니다. 실제 결제·제작·배송은 진행하지 않습니다.'),
          ],
          const SizedBox(height: 12),
          ExpansionTile(
            key: const ValueKey('print-review-pdf-tools'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              '검수용 PDF 보기·저장',
              style: ExperienceFormStyle.text(context, 13),
            ),
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _busy ||
                          _openingPhotoEditor ||
                          !_checkedLayout ||
                          _error != null
                      ? null
                      : _generate,
                  icon: const Icon(Icons.picture_as_pdf, size: 19),
                  label: const Text('표지·내지 검수용 PDF 만들기'),
                ),
              ),
              note('PDF는 제작 가이드와 대조하는 검수용 파일입니다. 저장만으로 주문이 접수되지는 않습니다.'),
              if (_export != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _share(
                    _export!.coverPdf,
                    'snapfit-${widget.albumId}-cover-review.pdf',
                  ),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('표지 PDF 보기·저장'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _share(
                    _export!.interiorPdf,
                    'snapfit-${widget.albumId}-interior-review.pdf',
                  ),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('내지 PDF 보기·저장'),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 24),
        Divider(color: ExperienceFormStyle.line(context)),
        const SizedBox(height: 16),
        const PrintFulfillmentNotice(),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _busy || _openingPhotoEditor
              ? null
              : () => Navigator.pop(context, 'edit_album'),
          child: const Text('앨범 계속 편집하기'),
        ),
      ],
    );
  }

  Widget _photoIssueCard(BuildContext context, PrintPhotoIssue issue) {
    final disabled =
        _loading ||
        _busy ||
        _openingCheckout ||
        _openingPhotoEditor ||
        _refreshingPrice;
    return Container(
      key: ValueKey(
        'print-photo-issue-${issue.target.pageIndex}-${issue.target.layerId}',
      ),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: ExperienceFormStyle.line(context)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            issue.label,
            style: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            issue.blocksPrinting
                ? '인쇄하려면 이 사진을 수정해 주세요.'
                : '이 크기로 인쇄하면 사진이 흐릿할 수 있어요.',
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
          if (issue.effectivePpi != null) ...[
            const SizedBox(height: 4),
            Text(
              '현재 ${issue.effectivePpi!.round()}ppi · 권장 ${issue.recommendedPpi}ppi',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                key: ValueKey(
                  'print-edit-photo-${issue.target.pageIndex}-${issue.target.layerId}',
                ),
                onPressed: disabled ? null : () => _editPhotoIssue(issue),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('이 사진 수정하기'),
              ),
              TextButton(
                onPressed: disabled ? null : () => _showPhotoIssue(issue),
                child: const Text('페이지 보기'),
              ),
            ],
          ),
        ],
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
  if (error is StateError &&
      (error.message == 'print_pdf_exceeds_vendor_limit' ||
          error.message == 'print_pdf_exceeds_90mb_limit')) {
    return '인쇄 파일이 제작 가능한 용량을 넘었어요. 표지는 최대 150MB, 내지는 최대 500MB입니다. 앨범 구성을 조정한 뒤 다시 확인해주세요.';
  }
  final message = error is PostgrestException
      ? error.message
      : error is FormatException
      ? error.message.toString()
      : '';
  if (message.contains('hardcover_template_required')) {
    return '하드커버 표지 제작 도면을 확인하는 중입니다. 확인 후 검수용 PDF를 만들 수 있습니다.';
  }
  if (message.contains('print_review_changed')) {
    return '앨범 내용이나 인쇄 규격이 바뀌었어요. 최신 정보로 미리보기를 다시 확인해주세요.';
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
      'print_checkout_pdf_too_large' =>
        '인쇄 파일이 제작 가능한 용량을 넘었어요. 표지는 최대 150MB, 내지는 최대 500MB입니다. 앨범 구성을 조정한 뒤 다시 확인해주세요.',
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
