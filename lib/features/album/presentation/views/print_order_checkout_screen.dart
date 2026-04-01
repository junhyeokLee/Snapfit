import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../profile/data/order_repository.dart';
import '../../../profile/domain/entities/order_history_item.dart';

class PrintOrderCheckoutScreen extends ConsumerStatefulWidget {
  const PrintOrderCheckoutScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.pageCount,
  });

  final int albumId;
  final String albumTitle;
  final int pageCount;

  @override
  ConsumerState<PrintOrderCheckoutScreen> createState() =>
      _PrintOrderCheckoutScreenState();
}

class _PrintOrderCheckoutScreenState
    extends ConsumerState<PrintOrderCheckoutScreen> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _zipController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _memoController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingQuote = true;
  bool _agreedPolicy = false;
  OrderHistoryItem? _order;
  OrderQuoteResult? _quote;

  final List<_PaymentMethodOption> _paymentMethods = const [
    _PaymentMethodOption(
      id: 'TOSS_PAYMENTS',
      title: '토스페이먼츠',
      subtitle: '카드/간편결제',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _PaymentMethodOption(
      id: 'NAVERPAY',
      title: '네이버페이',
      subtitle: '네이버 간편결제',
      icon: Icons.payments_rounded,
    ),
    _PaymentMethodOption(
      id: 'KG_INICIS',
      title: 'KG이니시스',
      subtitle: '카드/계좌이체',
      icon: Icons.credit_card_rounded,
    ),
  ];

  String _selectedPaymentId = 'TOSS_PAYMENTS';

  @override
  void initState() {
    super.initState();
    _initOrderDeepLinkListener();
    unawaited(_loadQuote());
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _initOrderDeepLinkListener() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      unawaited(_handleOrderCallbackUri(initial));
    }
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_handleOrderCallbackUri(uri));
    });
  }

  Future<void> _handleOrderCallbackUri(Uri uri) async {
    if (!mounted || _order == null) return;
    if (uri.scheme.toLowerCase() != 'snapfit' ||
        uri.host.toLowerCase() != 'order') {
      return;
    }
    final orderId = uri.queryParameters['orderId']?.trim() ?? '';
    if (orderId != _order!.orderId) return;
    final path = uri.path.toLowerCase();

    if (path.contains('success')) {
      // 결제 승인(confirm)은 앱 전역 딥링크 리스너(main.dart)에서 단일 처리한다.
      // 이 화면에서는 중복 호출을 피하고 결과 UI 전환만 담당한다.
      ref.invalidate(myOrderHistoryProvider);
      Navigator.pop(context, true);
      return;
    }
    if (path.contains('fail')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문 결제가 취소되거나 실패했습니다.')));
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_quote == null) {
      await _loadQuote();
      if (_quote == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('주문 금액을 불러오지 못했습니다.')));
        return;
      }
    }

    if (_order == null) {
      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }
      if (!_agreedPolicy) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('주문/배송 정보 수집에 동의해주세요.')));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final orderRepo = ref.read(orderRepositoryProvider);

      if (_order == null) {
        final created = await orderRepo.createPrintOrder(
          albumId: widget.albumId,
          title: widget.albumTitle.isNotEmpty ? widget.albumTitle : '스냅핏 포토북',
          amount: _quote!.amount,
          pageCount: _quote!.pageCount,
          paymentMethod: _selectedPaymentId,
          recipientName: _nameController.text.trim(),
          recipientPhone: _phoneController.text.trim(),
          zipCode: _zipController.text.trim(),
          addressLine1: _address1Controller.text.trim(),
          addressLine2: _address2Controller.text.trim(),
          deliveryMemo: _memoController.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _order = created;
        });
        ref.invalidate(myOrderHistoryProvider);
        await _openCheckout(orderRepo, created.orderId);
      } else if (_order!.status == 'PAYMENT_PENDING') {
        await _openCheckout(orderRepo, _order!.orderId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openCheckout(OrderRepository orderRepo, String orderId) async {
    final url = await orderRepo.buildOrderCheckoutUrl(
      orderId: orderId,
      paymentMethod: _selectedPaymentId,
    );
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 URL이 올바르지 않습니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제창을 열지 못했습니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('결제창을 열었습니다. 결제 완료 후 앱으로 자동 복귀합니다.')),
    );
  }

  Future<void> _loadQuote() async {
    setState(() => _isLoadingQuote = true);
    try {
      final quote = await ref
          .read(orderRepositoryProvider)
          .fetchOrderQuote(
            albumId: widget.albumId,
            pageCount: widget.pageCount,
          );
      if (!mounted) return;
      setState(() {
        _quote = quote;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quote = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuote = false);
      }
    }
  }

  String get _primaryButtonLabel {
    if (_order == null) return '주문 생성 후 결제하기';
    if (_order!.status == 'PAYMENT_PENDING') return '결제창 열기';
    return '주문 내역으로 돌아가기';
  }

  bool get _canCloseToHistory {
    final status = _order?.status;
    return status != null && status != 'PAYMENT_PENDING';
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _order?.statusLabel ?? '결제대기';

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          title: const Text('주문/결제'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isSubmitting,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(context, '주문 정보'),
                      _infoCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.albumTitle,
                              style: TextStyle(
                                color: SnapFitColors.textPrimaryOf(context),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _isLoadingQuote
                                  ? '앨범 ID ${widget.albumId}  ·  가격 계산중...'
                                  : '앨범 ID ${widget.albumId}  ·  ${(_quote?.pageCount ?? widget.pageCount)}p  ·  ${_formatAmount(_quote?.amount ?? 0)}원',
                              style: TextStyle(
                                color: SnapFitColors.textSecondaryOf(context),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!_isLoadingQuote && _quote == null) ...[
                              SizedBox(height: 8.h),
                              OutlinedButton.icon(
                                onPressed: _loadQuote,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('금액 다시 불러오기'),
                              ),
                            ],
                            SizedBox(height: 10.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: SnapFitColors.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: Text(
                                '현재 상태: $statusText',
                                style: TextStyle(
                                  color: SnapFitColors.accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 18.h),
                      _sectionTitle(context, '배송지 입력'),
                      _infoCard(
                        context,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _field(
                                _nameController,
                                '수령인',
                                enabled: _order == null,
                              ),
                              SizedBox(height: 10.h),
                              _field(
                                _phoneController,
                                '연락처',
                                enabled: _order == null,
                                keyboardType: TextInputType.phone,
                              ),
                              SizedBox(height: 10.h),
                              _field(
                                _zipController,
                                '우편번호',
                                enabled: _order == null,
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 8.h),
                              if (_order == null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _showAddressSearch,
                                    icon: const Icon(Icons.search_rounded),
                                    label: const Text('주소 검색'),
                                  ),
                                ),
                              SizedBox(height: 10.h),
                              _field(
                                _address1Controller,
                                '기본 주소',
                                enabled: _order == null,
                              ),
                              SizedBox(height: 10.h),
                              _field(
                                _address2Controller,
                                '상세 주소(선택)',
                                required: false,
                                enabled: _order == null,
                              ),
                              SizedBox(height: 10.h),
                              _field(
                                _memoController,
                                '배송 메모(선택)',
                                required: false,
                                enabled: _order == null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      _sectionTitle(context, '결제 수단'),
                      _infoCard(
                        context,
                        child: Column(
                          children: _paymentMethods
                              .map((m) => _paymentMethodTile(context, m))
                              .toList(),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      if (_order == null)
                        _infoCard(
                          context,
                          child: CheckboxListTile(
                            value: _agreedPolicy,
                            onChanged: (v) =>
                                setState(() => _agreedPolicy = v ?? false),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '주문 처리 및 배송을 위한 개인정보 수집에 동의합니다.',
                              style: TextStyle(
                                color: SnapFitColors.textPrimaryOf(context),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      if (_order == null) SizedBox(height: 18.h),
                      _sectionTitle(context, '진행 상태'),
                      _infoCard(
                        context,
                        child: _statusTimeline(context, _order?.status),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  if (_canCloseToHistory) {
                                    Navigator.pop(context, true);
                                    return;
                                  }
                                  _submit();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SnapFitColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _primaryButtonLabel,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      if (_order != null) ...[
                        SizedBox(height: 12.h),
                        Text(
                          '주문번호: ${_order!.orderId}  ·  결제수단: ${_paymentLabel(_selectedPaymentId)}',
                          style: TextStyle(
                            color: SnapFitColors.textMutedOf(context),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_isSubmitting)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.24),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 14.h,
                      ),
                      decoration: BoxDecoration(
                        color: SnapFitColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.4,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            '주문/결제 처리 중입니다...',
                            style: TextStyle(
                              color: SnapFitColors.textPrimaryOf(context),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return '로그인이 만료되었습니다. 다시 로그인 후 시도해주세요.';
      }
      if (status == 400) {
        return '입력 정보를 다시 확인해주세요.';
      }
      if (status == 409) {
        return '이미 처리된 주문입니다. 주문내역에서 상태를 확인해주세요.';
      }
      if (status == 429) {
        return '요청이 많습니다. 잠시 후 다시 시도해주세요.';
      }
      if (status != null && status >= 500) {
        return '서버가 불안정합니다. 잠시 후 다시 시도해주세요.';
      }
    }
    return '처리에 실패했습니다. 네트워크 상태를 확인하고 다시 시도해주세요.';
  }

  Future<void> _showAddressSearch() async {
    final selected = await showModalBottomSheet<AddressSearchItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => _AddressSearchSheet(
        onSearch: (keyword) async {
          final res = await ref
              .read(orderRepositoryProvider)
              .searchAddress(keyword: keyword);
          return res.items;
        },
      ),
    );

    if (selected == null || !mounted) return;
    final preferredRoad = selected.roadAddressPart1.isNotEmpty
        ? '${selected.roadAddressPart1}${selected.roadAddressPart2}'
        : selected.roadAddress;
    setState(() {
      _zipController.text = selected.zipCode;
      _address1Controller.text = preferredRoad.isNotEmpty
          ? preferredRoad
          : selected.jibunAddress;
    });
  }

  Widget _paymentMethodTile(BuildContext context, _PaymentMethodOption m) {
    final selected = _selectedPaymentId == m.id;
    return InkWell(
      onTap: _order == null
          ? () => setState(() {
              _selectedPaymentId = m.id;
            })
          : null,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected
                ? SnapFitColors.accent
                : SnapFitColors.overlayLightOf(context),
            width: selected ? 1.5 : 1,
          ),
          color: selected
              ? SnapFitColors.accent.withOpacity(0.06)
              : SnapFitColors.surfaceOf(context),
        ),
        child: Row(
          children: [
            Icon(m.icon, color: SnapFitColors.textPrimaryOf(context)),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    style: TextStyle(
                      color: SnapFitColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    m.subtitle,
                    style: TextStyle(
                      color: SnapFitColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? SnapFitColors.accent
                  : SnapFitColors.textMutedOf(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTimeline(BuildContext context, String? status) {
    const steps = <Map<String, String>>[
      {'id': 'PAYMENT_PENDING', 'label': '결제대기'},
      {'id': 'PAYMENT_COMPLETED', 'label': '결제완료'},
      {'id': 'IN_PRODUCTION', 'label': '제작중'},
      {'id': 'SHIPPING', 'label': '배송중'},
      {'id': 'DELIVERED', 'label': '배송완료'},
    ];

    int activeIndex = 0;
    if (status != null) {
      final idx = steps.indexWhere((e) => e['id'] == status);
      if (idx >= 0) activeIndex = idx;
    }

    return Column(
      children: List.generate(steps.length, (i) {
        final active = i <= activeIndex;
        return Padding(
          padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10.h),
          child: Row(
            children: [
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? SnapFitColors.accent
                      : SnapFitColors.overlayLightOf(context),
                ),
                child: Icon(Icons.check, color: Colors.white, size: 12.sp),
              ),
              SizedBox(width: 10.w),
              Text(
                steps[i]['label']!,
                style: TextStyle(
                  color: active
                      ? SnapFitColors.textPrimaryOf(context)
                      : SnapFitColors.textMutedOf(context),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(fontSize: 14.sp),
      inputFormatters: label == '연락처'
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ]
          : label == '우편번호'
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ]
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: SnapFitColors.surfaceOf(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: SnapFitColors.overlayLightOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: SnapFitColors.overlayLightOf(context)),
        ),
      ),
      validator: required
          ? (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) {
                return '$label을 입력해주세요.';
              }
              if (label == '연락처' && !RegExp(r'^\d{10,11}$').hasMatch(v)) {
                return '연락처는 숫자 10~11자리로 입력해주세요.';
              }
              if (label == '우편번호' && !RegExp(r'^\d{5}$').hasMatch(v)) {
                return '우편번호 5자리를 입력해주세요.';
              }
              return null;
            }
          : null,
    );
  }

  Widget _infoCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: TextStyle(
          color: SnapFitColors.textPrimaryOf(context),
          fontWeight: FontWeight.w800,
          fontSize: 15.sp,
        ),
      ),
    );
  }

  String _paymentLabel(String id) {
    final found = _paymentMethods.where((e) => e.id == id);
    if (found.isEmpty) return id;
    return found.first.title;
  }

  String _formatAmount(int amount) {
    final s = amount.toString();
    return s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _AddressSearchSheet extends StatefulWidget {
  const _AddressSearchSheet({required this.onSearch});

  final Future<List<AddressSearchItem>> Function(String keyword) onSearch;

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  List<AddressSearchItem> _items = const [];
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.length < 2) {
      setState(() {
        _error = '두 글자 이상 입력해주세요.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.onSearch(keyword);
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '주소 검색에 실패했습니다. 잠시 후 다시 시도해주세요.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16.w,
          12.h,
          16.w,
          MediaQuery.of(context).viewInsets.bottom + 16.h,
        ),
        child: SizedBox(
          height: 460.h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '주소 검색',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: '도로명/건물명/지번',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  FilledButton(
                    onPressed: _loading ? null : _search,
                    child: const Text('검색'),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
                ),
              if (_loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Text(
                            '검색 결과가 없습니다.',
                            style: TextStyle(
                              color: SnapFitColors.textMutedOf(context),
                              fontSize: 13.sp,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => Divider(height: 1.h),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              onTap: () => Navigator.pop(context, item),
                              title: Text(
                                item.roadAddress.isNotEmpty
                                    ? item.roadAddress
                                    : item.jibunAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('우편번호 ${item.zipCode}'),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodOption {
  const _PaymentMethodOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}
