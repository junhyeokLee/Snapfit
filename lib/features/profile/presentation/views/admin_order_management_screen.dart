import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/env.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../data/admin_ops_repository.dart';
import '../../../album/printing/album_print_exporter.dart';
import '../../data/order_repository.dart';
import '../../domain/entities/order_history_item.dart';

class AdminOrderManagementScreen extends ConsumerStatefulWidget {
  const AdminOrderManagementScreen({super.key});

  @override
  ConsumerState<AdminOrderManagementScreen> createState() =>
      _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState
    extends ConsumerState<AdminOrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  );
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  int _refreshSeed = 0;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() => _refreshSeed++);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _applyKeyword() {
    FocusScope.of(context).unfocus();
    setState(() {
      _keyword = _searchController.text.trim();
      _refreshSeed++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canAdminControl = Env.orderAdminKey.trim().isNotEmpty;
    if (!canAdminControl) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          backgroundColor: SnapFitColors.backgroundOf(context),
          elevation: 0,
          leading: const SnapFitAppBarBackButton(),
          title: Text('주문 관리', style: context.sfTitle(size: 16.sp)),
        ),
        body: Center(
          child: Text(
            '관리자 키가 설정되지 않았습니다.',
            style: TextStyle(
              fontSize: 13.sp,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text('주문 관리', style: context.sfTitle(size: 16.sp)),
        actions: [
          IconButton(
            onPressed: () => setState(() => _refreshSeed++),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(94.h),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _applyKeyword(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                  decoration: InputDecoration(
                    hintText: '주문번호, 앨범명, 수령인 검색',
                    hintStyle: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: _applyKeyword,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    filled: true,
                    fillColor: SnapFitColors.surfaceOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelPadding: EdgeInsets.symmetric(horizontal: 10.w),
                indicatorColor: SnapFitColors.accent,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelColor: SnapFitColors.textPrimaryOf(context),
                unselectedLabelColor: SnapFitColors.textSecondaryOf(context),
                labelStyle: context.sfBody(
                  size: 12.sp,
                  weight: FontWeight.w700,
                ),
                unselectedLabelStyle: context.sfSub(
                  size: 12.sp,
                  weight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: '전체'),
                  Tab(text: '결제완료'),
                  Tab(text: '제작중'),
                  Tab(text: '배송중'),
                  Tab(text: '완료/취소'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AdminOrderPagedTab(
            key: ValueKey('admin-all-$_keyword-$_refreshSeed'),
            statuses: const [],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
          _AdminOrderPagedTab(
            key: ValueKey('admin-paid-$_keyword-$_refreshSeed'),
            statuses: const ['PAYMENT_COMPLETED'],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
          _AdminOrderPagedTab(
            key: ValueKey('admin-prod-$_keyword-$_refreshSeed'),
            statuses: const ['IN_PRODUCTION'],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
          _AdminOrderPagedTab(
            key: ValueKey('admin-ship-$_keyword-$_refreshSeed'),
            statuses: const ['SHIPPING'],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
          _AdminOrderPagedTab(
            key: ValueKey('admin-done-$_keyword-$_refreshSeed'),
            statuses: const ['DELIVERED', 'CANCELED'],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderDetailSheet(OrderHistoryItem order) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PrintFulfillmentSheet(order: order),
    );
    if (changed == true && mounted) {
      setState(() => _refreshSeed++);
      ref.invalidate(myOrderHistoryProvider);
      ref.invalidate(myOrderSummaryProvider);
    }
  }
}

class _PrintFulfillmentSheet extends ConsumerStatefulWidget {
  const _PrintFulfillmentSheet({required this.order});
  final OrderHistoryItem order;

  @override
  ConsumerState<_PrintFulfillmentSheet> createState() =>
      _PrintFulfillmentSheetState();
}

class _PrintFulfillmentSheetState
    extends ConsumerState<_PrintFulfillmentSheet> {
  late OrderHistoryItem _order = widget.order;
  bool _busy = false;
  bool _changed = false;
  Map<String, dynamic>? _costEvaluation;
  String? _error;
  String? _progress;

  AdminOpsRepository get _repo => ref.read(adminOpsRepositoryProvider);
  String get _adminKey => Env.orderAdminKey;

  Future<void> _run(Future<OrderHistoryItem> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _order = updated;
        _changed = true;
        _costEvaluation = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = AppErrorMapper.toUserMessage(e));
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = null;
        });
    }
  }

  Future<void> _generate() => _run(() async {
    setState(() => _progress = '주문할 때 저장한 앨범을 불러오는 중');
    final source = await _repo.getPrintSnapshot(
      adminKey: _adminKey,
      orderId: _order.orderId,
    );
    final spec = PrintVendorSpec.fromJson(
      Map<String, dynamic>.from(source['spec'] as Map),
    );
    final output = await AlbumPrintExporter().generate(
      snapshot: Map<String, dynamic>.from(source['snapshot'] as Map),
      sourceUrls: Map<String, String>.from(
        source['sourceUrls'] as Map? ?? const {},
      ),
      spec: spec,
      onProgress: (completed, total) {
        if (mounted)
          setState(
            () => _progress = '사진과 글씨를 인쇄 파일로 만드는 중 $completed / $total',
          );
      },
    );
    final upload = await _repo.createPrintUploads(
      adminKey: _adminKey,
      orderId: _order.orderId,
    );
    if (upload['sourceFingerprint'] != source['sourceFingerprint']) {
      throw StateError('주문 인쇄 정보가 변경되었습니다. 다시 생성해주세요.');
    }
    if (mounted) setState(() => _progress = '표지와 내지 PDF를 안전하게 업로드하는 중');
    await _repo.uploadPrintPdfs(
      upload: upload,
      coverPdf: output.coverPdf,
      interiorPdf: output.interiorPdf,
    );
    return _repo.finalizePrintPackage(
      adminKey: _adminKey,
      orderId: _order.orderId,
      uploadId: upload['uploadId'].toString(),
      manifest: {
        ...output.report,
        'sourceFingerprint': source['sourceFingerprint'],
        'pageCount': output.interiorPageCount,
      },
    );
  });

  Future<void> _openPdf(String key) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final links = await _repo.getPrintDownloadLinks(
        adminKey: _adminKey,
        orderId: _order.orderId,
      );
      final uri = Uri.tryParse(links[key]?.toString() ?? '');
      if (uri == null || uri.scheme != 'https')
        throw StateError('PDF 다운로드 주소를 받지 못했습니다.');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('PDF를 열지 못했습니다.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppErrorMapper.toUserMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configureSpec() async {
    if (_busy) return;
    final product = _order.printProduct;
    final hard = product?.isHardcover == true;
    late final PrintVendorSpec currentSpec;
    setState(() {
      _busy = true;
      _error = null;
      _progress = '주문의 제작 도면을 불러오는 중';
    });
    try {
      final source = await _repo.getPrintSnapshot(
        adminKey: _adminKey,
        orderId: _order.orderId,
      );
      currentSpec = PrintVendorSpec.fromJson(
        Map<String, dynamic>.from(source['spec'] as Map),
      );
      if (product == null || currentSpec.id != product.id) {
        throw const FormatException('print_product_spec_mismatch');
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = '이 주문의 제작 도면을 불러오지 못했습니다. 다시 확인해주세요.');
      return;
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = null;
        });
    }
    if (!mounted) return;
    final initialSpine =
        (currentSpec.data['spineMm'] as num?)?.toDouble() ??
        currentSpec.front.left - currentSpec.back.right;
    final spine = TextEditingController(text: initialSpine.toStringAsFixed(2));
    final evidence = TextEditingController();
    final geometry = TextEditingController(
      text: hard
          ? const JsonEncoder.withIndent(
              '  ',
            ).convert(currentSpec.toJson()['cover'])
          : '',
    );
    var advancedEdited = false;
    final autoGeometry = currentSpec.hasOfficialHardcoverProfile;
    void adjustSpine(String value) {
      final parsed = double.tryParse(value);
      if (hard &&
          autoGeometry &&
          !advancedEdited &&
          parsed != null &&
          parsed >= .1 &&
          parsed <= 40) {
        geometry.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(currentSpec.officialCoverGeometryForSpine(parsed));
      }
    }

    Map<String, dynamic>? validatedGeometry() {
      if (!hard) return null;
      try {
        final value = Map<String, dynamic>.from(
          jsonDecode(geometry.text) as Map,
        );
        value['construction'] = 'casewrap';
        final validated = PrintVendorSpec.fromJson({
          'id': product!.id,
          'specVersion': '${product.id}_REVIEW_V3_ADMIN_VALIDATION',
          'geometrySource': currentSpec.data['geometrySource'],
          'pageCount': _order.pageCount,
          'interior': {
            'trimWidthMm': product.trimWidthMm,
            'trimHeightMm': product.trimHeightMm,
            'bleedMm': 5,
          },
          'cover': value,
        });
        final requestedSpine = double.tryParse(spine.text);
        if (requestedSpine == null ||
            (validated.front.left - validated.back.right - requestedSpine)
                    .abs() >
                .01)
          return null;
        return value;
      } catch (_) {
        return null;
      }
    }

    final result =
        await showDialog<
          ({double spine, String evidence, Map<String, dynamic>? coverGeometry})
        >(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
              title: const Text('페이지 수에 맞는 업체 도면 확인'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '레드프린팅에서 ${_order.printProductLabel}, 내지 ${_order.pageCount}페이지로 내려받은 도면의 책등 값을 입력하세요. 변경하면 PDF를 다시 생성해야 합니다.',
                    ),
                    TextField(
                      controller: spine,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) => update(() => adjustSpine(value)),
                      decoration: const InputDecoration(
                        labelText: '공식 도면의 책등 폭',
                        suffixText: 'mm',
                      ),
                    ),
                    if (hard) ...[
                      const SizedBox(height: 12),
                      Text(
                        autoGeometry
                            ? '표지 규격을 불러왔습니다. 책등 폭을 바꾸면 앞표지 위치와 전체 폭이 함께 맞춰집니다.'
                            : '이 주문에 저장된 조정 도면입니다. 책등 폭을 변경하려면 세부 도면도 함께 확인해주세요.',
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('세부 도면 조정'),
                        children: [
                          TextField(
                            controller: geometry,
                            minLines: 5,
                            maxLines: 12,
                            onChanged: (_) =>
                                update(() => advancedEdited = true),
                            decoration: const InputDecoration(
                              labelText: '표지 규격 (JSON, mm)',
                              helperText:
                                  'widthMm, heightMm, bleedMm, front, back, trim\n각 사각형: xMm, yMm, widthMm, heightMm',
                            ),
                          ),
                          if (validatedGeometry() == null)
                            const Text(
                              '도면의 표지 영역과 재단 영역을 확인해주세요.',
                              style: TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ],
                    TextField(
                      controller: evidence,
                      minLines: 2,
                      maxLines: 4,
                      onChanged: (_) => update(() {}),
                      decoration: const InputDecoration(
                        labelText: '확인한 도면 이름·출처·날짜 (10자 이상)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed:
                      (double.tryParse(spine.text) ?? 0) >= .1 &&
                          (double.tryParse(spine.text) ?? 100) <= 40 &&
                          evidence.text.trim().length >= 10 &&
                          (!hard ||
                              (validatedGeometry() != null &&
                                  (autoGeometry ||
                                      advancedEdited ||
                                      ((double.tryParse(spine.text) ?? 0) -
                                                  initialSpine)
                                              .abs() <
                                          .001)))
                      ? () => Navigator.pop(ctx, (
                          spine: double.parse(spine.text),
                          evidence: evidence.text.trim(),
                          coverGeometry: validatedGeometry(),
                        ))
                      : null,
                  child: const Text('규격 저장'),
                ),
              ],
            ),
          ),
        );
    spine.dispose();
    evidence.dispose();
    geometry.dispose();
    if (result != null && mounted)
      await _run(
        () => _repo.configurePrintSpec(
          adminKey: _adminKey,
          orderId: _order.orderId,
          spineMm: result.spine,
          evidence: result.evidence,
          coverGeometry: result.coverGeometry,
        ),
      );
  }

  Future<void> _review() async {
    final note = TextEditingController();
    bool confirmed = false;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('인쇄 파일 검수 완료'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '레드프린팅에서 받은 해당 규격의 표지·내지 작업 가이드와 PDF를 대조하세요. 책등, 재단 여백, 페이지 순서, 사진·글씨 누락을 확인한 결과를 남깁니다.',
                ),
                CheckboxListTile(
                  value: confirmed,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) => update(() => confirmed = value == true),
                  title: const Text('해당 상품의 파일 규격·색상과 실물 샘플 확인 근거를 검토했습니다.'),
                ),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => update(() {}),
                  decoration: const InputDecoration(
                    labelText: '규격·색상·실물 샘플 확인 근거 / 가이드 버전 (10자 이상)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: confirmed && note.text.trim().length >= 10
                  ? () => Navigator.pop(ctx, note.text.trim())
                  : null,
              child: const Text('검수 기록 저장'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    if (result == null || !mounted) return;
    await _run(
      () => _repo.markPrintReviewed(
        adminKey: _adminKey,
        orderId: _order.orderId,
        reviewNote: result,
      ),
    );
  }

  Future<void> _evaluateCosts() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PrintCostEstimateDialog(
        evaluate: (print, shipping, packaging) => _repo.evaluatePrintCosts(
          adminKey: _adminKey,
          orderId: _order.orderId,
          actualPrintCost: print,
          actualShippingCost: shipping,
          actualPackagingCost: packaging,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _costEvaluation = result);
  }

  Future<void> _submitVendor() async {
    final submitted = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _VendorSubmissionDialog(order: _order),
    );
    if (submitted == null || !mounted) return;
    await _run(
      () => _repo.submitPrintVendor(
        adminKey: _adminKey,
        orderId: _order.orderId,
        vendorOrderId: submitted['vendorOrderId'] as String,
        actualPrintCost: submitted['actualPrintCost'] as int,
        actualShippingCost: submitted['actualShippingCost'] as int,
        actualPackagingCost: submitted['actualPackagingCost'] as int,
        fulfillmentMethod: submitted['fulfillmentMethod'] as String,
        senderLabelConfirmed: submitted['senderLabelConfirmed'] as bool,
        priceSlipOmittedConfirmed:
            submitted['priceSlipOmittedConfirmed'] as bool,
        promotionalMaterialsOmittedConfirmed:
            submitted['promotionalMaterialsOmittedConfirmed'] as bool,
        vendorSpecConfirmed: submitted['vendorSpecConfirmed'] as bool,
        confirmationNote: submitted['confirmationNote'] as String,
      ),
    );
  }

  Future<void> _acceptVendor() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제작사 접수 확인'),
        content: Text(
          '레드프린팅 주문 ${_order.printVendorOrderId ?? ''}의 접수·제작 진행을 실제로 확인했나요? 확인 내용을 저장하면 고객에게 제작중으로 표시됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('아직 확인 전'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('접수 확인 완료'),
          ),
        ],
      ),
    );
    if (ok == true && mounted)
      await _run(
        () => _repo.acceptPrintVendor(
          adminKey: _adminKey,
          orderId: _order.orderId,
        ),
      );
  }

  Future<void> _shipping() async {
    final courier = TextEditingController(text: _order.courier ?? '');
    final tracking = TextEditingController(text: _order.trackingNumber ?? '');
    final shipping = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('배송 시작'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: courier,
                onChanged: (_) => update(() {}),
                decoration: const InputDecoration(labelText: '실제 택배사'),
              ),
              TextField(
                controller: tracking,
                onChanged: (_) => update(() {}),
                decoration: const InputDecoration(labelText: '실제 운송장 번호'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed:
                  courier.text.trim().isNotEmpty &&
                      tracking.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, {
                      'courier': courier.text.trim(),
                      'tracking': tracking.text.trim(),
                    })
                  : null,
              child: const Text('배송 정보 저장'),
            ),
          ],
        ),
      ),
    );
    courier.dispose();
    tracking.dispose();
    if (shipping != null && mounted)
      await _run(
        () => _repo.markShipping(
          adminKey: _adminKey,
          orderId: _order.orderId,
          courier: shipping['courier']!,
          trackingNumber: shipping['tracking']!,
        ),
      );
  }

  Future<void> _copyOrder() async {
    final lines = [
      'SnapFit 주문번호: ${_order.orderId}',
      '레드프린팅 내 파일 포토북 / ${_order.printProductLabel} / 1권',
      '제작 상품: ${_order.printProduct?.id ?? '확인 필요'}',
      '내지 ${_order.pageCount ?? '-'}페이지 · 표지 PDF와 내지 PDF 별도 업로드',
      '운영자 경유 배송이면 업체 수령지는 운영자 주소로 직접 입력하세요. 아래는 최종 고객 배송정보입니다.',
      '수령인: ${_order.recipientName ?? ''}',
      '연락처: ${_order.recipientPhone ?? ''}',
      '우편번호: ${_order.zipCode ?? ''}',
      '주소: ${_order.addressLine1 ?? ''} ${_order.addressLine2 ?? ''}',
      '배송 메모: ${_order.deliveryMemo ?? ''}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발주 입력 정보를 복사했습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    final paid = _order.status == 'PAYMENT_COMPLETED';
    final stage = _order.printFulfillmentStatus;
    final warnings = (_order.printManifest['warnings'] as List?) ?? const [];
    final confirmations = _order.fulfillmentConfirmation;
    String evidence(String key) => confirmations[key] == true ? '확인됨' : '미확인';
    return PopScope(
      canPop: !_busy,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '인쇄 발주 관리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, _changed),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_progress ?? '처리중...'),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: AbsorbPointer(
                    absorbing: _busy,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_order.orderId} · ${_order.statusLabel}'),
                        const SizedBox(height: 8),
                        Text(
                          _order.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(_order.fulfillmentLabel),
                        const SizedBox(height: 16),
                        const Text(
                          '1. 표지와 내지 PDF 준비',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${_order.printProductLabel} · 내지 20~80페이지(짝수)\n결제한 시점의 앨범으로 생성합니다.',
                        ),
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://www.redprinting.co.kr/ko/product/item/PH/PHBKMYB',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.info_outline),
                          label: const Text('업체 작업 가이드·견적 확인'),
                        ),
                        if (paid &&
                            !const ['SUBMITTED', 'ACCEPTED'].contains(stage))
                          OutlinedButton(
                            onPressed: _configureSpec,
                            child: const Text('공식 도면의 책등 폭 확인·입력'),
                          ),
                        if (paid &&
                            !const ['SUBMITTED', 'ACCEPTED'].contains(stage))
                          FilledButton.icon(
                            onPressed: _busy ? null : _generate,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: Text(
                              _order.hasPrintFiles
                                  ? '표지·내지 PDF 다시 생성'
                                  : '표지·내지 PDF 생성',
                            ),
                          ),
                        if (_order.hasPrintFiles)
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _openPdf('coverPdfUrl'),
                                child: const Text('표지 PDF 다운로드'),
                              ),
                              OutlinedButton(
                                onPressed: () => _openPdf('interiorPdfUrl'),
                                child: const Text('내지 PDF 다운로드'),
                              ),
                            ],
                          ),
                        if (_order.hasPrintFiles)
                          const Text(
                            '다운로드 링크는 15분간 유효합니다. 제작사에는 내려받은 PDF 파일을 업로드하세요.',
                          ),
                        for (final warning in warnings)
                          Text(
                            '• $warning',
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                        if (paid && stage == 'REVIEW_REQUIRED')
                          FilledButton.tonal(
                            onPressed: _review,
                            child: const Text('PDF·작업 규격 검수 기록'),
                          ),
                        const Divider(height: 32),
                        const Text(
                          '2. 레드프린팅에 직접 주문',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Text('준비된 두 PDF로 주문하고 실제 주문번호와 비용을 기록합니다.'),
                        if (paid && stage == 'READY') ...[
                          OutlinedButton(
                            onPressed: _evaluateCosts,
                            child: const Text('발주 전 예상 비용·공헌금액 확인'),
                          ),
                          if (_costEvaluation != null)
                            Text(
                              '예상 공헌금액 ${_won((_costEvaluation!['contributionMargin'] as num).toInt())}원 · 최소 기준 ${_won((_costEvaluation!['minContributionMargin'] as num).toInt())}원',
                            ),
                          const Text('인쇄비·총 배송비·포장비를 먼저 확인하면 업체 주문 페이지가 열립니다.'),
                        ],
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  paid &&
                                      stage == 'READY' &&
                                      _costEvaluation?['eligible'] == true
                                  ? () => launchUrl(
                                      Uri.parse(
                                        'https://www.redprinting.co.kr/ko/product/item/PH/PHBKMYB',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    )
                                  : null,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('레드프린팅 주문 페이지'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _copyOrder,
                              icon: const Icon(Icons.copy),
                              label: const Text('고객 배송정보·규격 복사'),
                            ),
                          ],
                        ),
                        Text(
                          '발송인 SnapFit 표기: ${evidence('senderLabelConfirmed')}\n금액 명세서 제외: ${evidence('priceSlipOmittedConfirmed')}\n홍보물 동봉 제외: ${evidence('promotionalMaterialsOmittedConfirmed')}\n업체 작업 규격: ${evidence('vendorSpecConfirmed')}',
                        ),
                        if (confirmations['evidence'] != null)
                          Text('확인 근거: ${confirmations['evidence']}'),
                        const Text(
                          '미확인 항목은 업체와 확인 후 기록합니다. 고객 직배송 조건을 확인하지 못한 경우 운영자가 받아 검수·재포장 후 발송합니다.',
                        ),
                        if (paid && stage == 'READY')
                          FilledButton(
                            onPressed: _submitVendor,
                            child: const Text('실제 발주번호·비용 기록'),
                          ),
                        if ((_order.printVendorOrderId ?? '').isNotEmpty)
                          Text('제작사 주문번호: ${_order.printVendorOrderId}'),
                        if (_order.fulfillmentMethod != null)
                          Text(
                            '배송 방식: ${_order.fulfillmentMethod == 'DIRECT' ? '제작사에서 고객에게 직배송' : '운영자 검수·재포장 후 배송'}',
                          ),
                        if (_order.actualPrintCost != null) ...[
                          Text(
                            '실제 제작비: ${_won(_order.actualPrintCost!)}원 / 배송비: ${_won(_order.actualShippingCost ?? 0)}원 / 포장비: ${_won(_order.actualPackagingCost ?? 0)}원',
                          ),
                          if (_order.contributionMargin != null)
                            Text(
                              '비용 반영 후 예상 공헌금액: ${_won(_order.contributionMargin!)}원',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          const Text(
                            '인건비·세금·고정비 등을 모두 차감한 순이익이 아닙니다. 등록된 비용과 수수료 추정치를 기준으로 계산합니다.',
                          ),
                        ],
                        const Divider(height: 32),
                        const Text(
                          '3. 제작사 접수 확인 → 배송',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (paid && stage == 'SUBMITTED')
                          FilledButton(
                            onPressed: _acceptVendor,
                            child: const Text('제작사 접수 확인 완료'),
                          ),
                        if (_order.status == 'IN_PRODUCTION')
                          FilledButton(
                            onPressed: _shipping,
                            child: const Text('택배사·운송장 등록'),
                          ),
                        if (_order.status == 'SHIPPING')
                          FilledButton(
                            onPressed: () => _run(
                              () => _repo.markDelivered(
                                adminKey: _adminKey,
                                orderId: _order.orderId,
                              ),
                            ),
                            child: const Text('실제 배송완료 확인'),
                          ),
                        if (_order.printAcceptedAt != null)
                          Text('제작사 접수: ${_order.printAcceptedAt!.toLocal()}'),
                        if (_order.trackingNumber != null)
                          Text(
                            '${_order.courier ?? ''} ${_order.trackingNumber}',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _won(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);

class _VendorSubmissionDialog extends StatefulWidget {
  const _VendorSubmissionDialog({required this.order});
  final OrderHistoryItem order;
  @override
  State<_VendorSubmissionDialog> createState() =>
      _VendorSubmissionDialogState();
}

class _VendorSubmissionDialogState extends State<_VendorSubmissionDialog> {
  final _form = GlobalKey<FormState>();
  final _vendor = TextEditingController();
  final _print = TextEditingController();
  final _shipping = TextEditingController();
  final _packaging = TextEditingController();
  final _note = TextEditingController();
  String _method = 'REPACK';
  bool _sender = false;
  bool _priceSlip = false;
  bool _promotionalMaterials = false;
  bool _spec = false;

  @override
  void dispose() {
    for (final controller in [_vendor, _print, _shipping, _packaging, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _cost(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, suffixText: '원'),
    validator: (value) {
      final amount = int.tryParse(value ?? '');
      return amount == null || amount < 0
          ? '실제 금액을 입력해주세요. 비용이 없으면 0을 입력하세요.'
          : null;
    },
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('실제 발주 기록'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('레드프린팅에서 주문을 마친 후 실제 번호와 영수증 기준 비용을 입력하세요.'),
              TextFormField(
                controller: _vendor,
                decoration: const InputDecoration(labelText: '레드프린팅 실제 주문번호'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? '제작사 주문번호가 필요합니다.' : null,
              ),
              _cost(_print, '실제 인쇄·제본비 (부가세 포함)'),
              _cost(_shipping, '실제 배송비 합계 (재배송 포함)'),
              _cost(_packaging, '실제 포장비'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '배송 방식'),
                items: const [
                  DropdownMenuItem(
                    value: 'REPACK',
                    child: Text('운영자 수령·검수·재포장 배송'),
                  ),
                  DropdownMenuItem(
                    value: 'DIRECT',
                    child: Text('제작사 → 고객 직배송'),
                  ),
                ],
                onChanged: (value) => setState(() => _method = value!),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sender,
                onChanged: (v) => setState(() => _sender = v == true),
                title: const Text('발송인 SnapFit 표기 확인'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _priceSlip,
                onChanged: (v) => setState(() => _priceSlip = v == true),
                title: const Text('금액 명세서 동봉 제외 확인'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _promotionalMaterials,
                onChanged: (v) =>
                    setState(() => _promotionalMaterials = v == true),
                title: const Text('제작사 홍보물 동봉 제외 확인'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _spec,
                onChanged: (v) => setState(() => _spec = v == true),
                title: const Text('업체 작업 규격·PDF 확인'),
              ),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '확인 근거 (상담 날짜·답변·주문 메모)',
                ),
                validator: (v) => (v ?? '').trim().length < 10
                    ? '확인 근거를 10자 이상 남겨주세요.'
                    : null,
              ),
              if (_method == 'DIRECT')
                const Text('직배송은 위 네 항목을 모두 확인한 경우에 기록할 수 있습니다.'),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed:
            _spec &&
                (_method != 'DIRECT' ||
                    (_sender && _priceSlip && _promotionalMaterials))
            ? () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(context, <String, dynamic>{
                  'vendorOrderId': _vendor.text.trim(),
                  'actualPrintCost': int.parse(_print.text),
                  'actualShippingCost': int.parse(_shipping.text),
                  'actualPackagingCost': int.parse(_packaging.text),
                  'fulfillmentMethod': _method,
                  'senderLabelConfirmed': _sender,
                  'priceSlipOmittedConfirmed': _priceSlip,
                  'promotionalMaterialsOmittedConfirmed': _promotionalMaterials,
                  'vendorSpecConfirmed': _spec,
                  'confirmationNote': _note.text.trim(),
                });
              }
            : null,
        child: const Text('발주 기록 저장'),
      ),
    ],
  );
}

class _AdminOrderPagedTab extends ConsumerStatefulWidget {
  const _AdminOrderPagedTab({
    super.key,
    required this.statuses,
    required this.keyword,
    required this.onShowDetail,
  });

  final List<String> statuses;
  final String keyword;
  final void Function(OrderHistoryItem order) onShowDetail;

  @override
  ConsumerState<_AdminOrderPagedTab> createState() =>
      _AdminOrderPagedTabState();
}

class _AdminOrderPagedTabState extends ConsumerState<_AdminOrderPagedTab> {
  static const int _pageSize = 20;
  late final ScrollController _scrollController;
  int _page = 0;
  bool _hasNext = true;
  bool _loadingMore = false;
  bool _initialLoading = true;
  String? _loadError;
  final List<OrderHistoryItem> _items = <OrderHistoryItem>[];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    Future.microtask(_loadFirst);
  }

  @override
  void didUpdateWidget(covariant _AdminOrderPagedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final statusChanged =
        oldWidget.statuses.join(',') != widget.statuses.join(',');
    final keywordChanged = oldWidget.keyword != widget.keyword;
    if (statusChanged || keywordChanged) {
      Future.microtask(_loadFirst);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasNext || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _initialLoading = true;
      _loadingMore = false;
      _loadError = null;
      _page = 0;
      _hasNext = true;
      _items.clear();
    });
    await _loadMore();
    if (!mounted) return;
    setState(() => _initialLoading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);
    try {
      final result = await ref
          .read(adminOpsRepositoryProvider)
          .fetchAdminOrders(
            adminKey: Env.orderAdminKey,
            statuses: widget.statuses,
            keyword: widget.keyword,
            page: _page,
            size: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page += 1;
        _hasNext = result.hasNext;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasNext = false;
        _loadError = e.toString();
      });
    }
    if (!mounted) return;
    setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      if (_loadError != null) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '주문 목록을 불러오지 못했습니다.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: SnapFitColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '네트워크 상태를 확인하고 다시 시도해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: SnapFitColors.textSecondaryOf(context),
                  ),
                ),
                SizedBox(height: 10.h),
                OutlinedButton.icon(
                  onPressed: _loadFirst,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Text(
          '조건에 맞는 주문이 없습니다.',
          style: TextStyle(
            fontSize: 12.sp,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
        itemCount: _items.length + (_hasNext ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final order = _items[index];
          return InkWell(
            onTap: () => widget.onShowDetail(order),
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _statusChip(context, order.statusLabel),
                      const Spacer(),
                      Text(
                        order.orderId,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: SnapFitColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    order.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${order.recipientName ?? '-'} · ${order.recipientPhone ?? '-'}',
                    style: TextStyle(
                      fontSize: 10.8.sp,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${order.fulfillmentLabel} · 표지/내지 ${order.hasPrintFiles ? '준비됨' : '미생성'}',
                    style: TextStyle(
                      fontSize: 10.2.sp,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(BuildContext context, String statusLabel) {
    final isDone = statusLabel == '배송완료';
    final isWarning = statusLabel == '취소';
    final color = isDone
        ? SnapFitColors.freezeAccentDark
        : isWarning
        ? SnapFitColors.error
        : SnapFitColors.accent;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          fontSize: 9.8.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _PrintCostEstimateDialog extends StatefulWidget {
  const _PrintCostEstimateDialog({required this.evaluate});
  final Future<Map<String, dynamic>> Function(
    int print,
    int shipping,
    int packaging,
  )
  evaluate;
  @override
  State<_PrintCostEstimateDialog> createState() =>
      _PrintCostEstimateDialogState();
}

class _PrintCostEstimateDialogState extends State<_PrintCostEstimateDialog> {
  final _form = GlobalKey<FormState>();
  final _print = TextEditingController();
  final _shipping = TextEditingController();
  final _packaging = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  @override
  void dispose() {
    _print.dispose();
    _shipping.dispose();
    _packaging.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.evaluate(
        int.parse(_print.text),
        int.parse(_shipping.text),
        int.parse(_packaging.text),
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = AppErrorMapper.toUserMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, suffixText: '원'),
        onChanged: (_) => setState(() => _result = null),
        validator: (value) => int.tryParse(value ?? '') == null
            ? '확인한 금액을 입력해주세요. 없으면 0을 입력하세요.'
            : null,
      );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('발주 전에 비용 확인'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '업체 견적을 입력해 발주 가능한 금액인지 확인하세요. 재포장 배송은 업체→운영자와 운영자→고객 배송비를 합산합니다.',
              ),
              _field(_print, '예상 인쇄·제본비 (부가세 포함)'),
              _field(_shipping, '예상 총 배송비 (재배송 포함)'),
              _field(_packaging, '예상 포장비'),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_result != null) ...[
                const SizedBox(height: 12),
                Text(
                  '예상 공헌금액 ${_won((_result!['contributionMargin'] as num).toInt())}원',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '최소 공헌금액 ${_won((_result!['minContributionMargin'] as num).toInt())}원',
                ),
                Text(
                  '결제수수료 준비금 ${_won((_result!['paymentFeeReserve'] as num).toInt())}원\n재제작 준비금 ${_won((_result!['reprintReserve'] as num).toInt())}원\n운영비 준비금 ${_won((_result!['operationsReserve'] as num).toInt())}원 반영',
                ),
                Text(
                  _result!['eligible'] == true
                      ? '현재 견적은 발주 기준을 충족합니다.'
                      : '현재 견적은 최소 기준에 못 미칩니다. 발주 전에 비용과 판매가격을 조정하세요.',
                  style: TextStyle(
                    color: _result!['eligible'] == true
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                const Text('순이익 보장이 아닙니다. 실제 비용은 제작사 주문 후 다시 기록합니다.'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _calculate,
          child: const Text('서버 견적 확인'),
        ),
        FilledButton(
          onPressed: !_busy && _result?['eligible'] == true
              ? () => Navigator.pop(context, _result)
              : null,
          child: const Text('이 견적으로 발주 준비'),
        ),
      ],
    ),
  );
}
