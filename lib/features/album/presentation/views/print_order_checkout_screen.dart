import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;
import '../../../../core/commerce/commerce_policy.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../profile/presentation/widgets/customer_web_page.dart';
import '../../../profile/data/order_repository.dart';
import '../../../profile/data/customer_print_test_checkout.dart';
import '../../../profile/data/print_dev_checkout.dart';
import '../../../profile/data/print_payment_service.dart';
import '../../../profile/data/portone_payment_launcher.dart';
import '../../../profile/domain/print_checkout.dart';
import '../../../profile/domain/print_checkout_consent.dart';
import '../../../profile/domain/print_order_request.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../../profile/presentation/views/print_order_request_screen.dart';
import '../../../profile/presentation/views/order_history_screen.dart';
import '../../../profile/presentation/views/terms_policy_screen.dart';
import '../../printing/print_vendor_spec.dart';
import 'print_order_complete_screen.dart';

/// Keeps delivery details in this route until a supported payment is submitted.
class PrintOrderCheckoutScreen extends ConsumerStatefulWidget {
  const PrintOrderCheckoutScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.initialQuote,
    required this.reviewedRevision,
    this.onPay,
    this.testMode = false,
    this.onOpenTestOrder,
  });

  final int albumId;
  final String albumTitle;
  final OrderQuoteResult initialQuote;
  final String reviewedRevision;
  final bool testMode;
  final ValueChanged<String>? onOpenTestOrder;

  final Future<PrintPaidReceipt?> Function(PrintCheckoutRequest request)? onPay;

  @override
  ConsumerState<PrintOrderCheckoutScreen> createState() =>
      _PrintOrderCheckoutScreenState();
}

class _PrintOrderCheckoutScreenState
    extends ConsumerState<PrintOrderCheckoutScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _zip = TextEditingController();
  final _address = TextEditingController();
  final _detail = TextEditingController();
  final _memo = TextEditingController();
  final _scroll = ScrollController();
  late OrderQuoteResult _quote = widget.initialQuote;
  PrintCheckoutReadiness? _readiness;
  bool _loading = false;
  bool _paying = false;
  bool _reviewing = false;
  bool _agreed = false;
  bool _policyAccepted = false;
  bool _customProductionAccepted = false;
  bool _reviewChanged = false;
  String? _error;
  String? _notice;
  String? _preparationNotice;
  bool _preparationRequiresRestart = false;
  String? _fileProgress;
  bool _pendingPayment = false;
  bool _pendingCanResume = false;
  bool _pendingSdkStarted = true;
  bool _pendingCustomerRequestHold = false;
  PrintOrderRequestTarget? _pendingTarget;
  String? _pendingOrderId;
  bool _recoveringPayment = false;
  Timer? _recoveryTimer;
  CustomerPrintTestCapability? _testCapability;
  PrintDevCheckoutSession? _testSession;
  bool _testSdkStarted = false;
  bool _testRecoveryUnknown = false;
  String? _ownerId;
  bool get _ownerCurrent =>
      _ownerId != null && ref.read(visibleOrderOwnerProvider) == _ownerId;

  CustomerPrintTestCheckoutService get _testService =>
      ref.read(customerPrintTestCheckoutServiceProvider);

  bool get _testFileChecked =>
      _testSession?.verifiedTest == true &&
      _testSession?.stage == 'FILE_CHECKED' &&
      _testSession?.devOrderNum != null;

  // The server has already frozen this address. Editing it would conflict with
  // the same idempotent invoice instead of updating the order.
  bool get _deliveryLocked => widget.testMode
      ? _testSession != null || _testRecoveryUnknown
      : _pendingPayment && _pendingOrderId != null;

  bool get _paymentAvailable => widget.testMode
      ? _testCapability != null &&
            !_testSdkStarted &&
            !_testRecoveryUnknown &&
            _testSession?.verifiedTest != true
      : _readiness?.canPay == true;

  PrintCheckoutConsent get _consent => PrintCheckoutConsent(
    orderReviewed: _agreed,
    policyAccepted: _policyAccepted,
    customProductionAccepted: _customProductionAccepted,
  );

  void _clearConsent() {
    _agreed = false;
    _policyAccepted = false;
    _customProductionAccepted = false;
  }

  void _revealOrderNotice() {
    if (!_reviewing ||
        (_error == null &&
            _notice == null &&
            _preparationNotice == null &&
            !_reviewChanged &&
            !_pendingPayment)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ownerCurrent || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  bool get _canPay =>
      _ownerCurrent &&
      !_loading &&
      !_paying &&
      (!_pendingPayment || _pendingCanResume) &&
      !_pendingCustomerRequestHold &&
      !_preparationRequiresRestart &&
      !_recoveringPayment &&
      !_reviewChanged &&
      _error == null &&
      _paymentAvailable &&
      _quote.hasPlannedRetailPrice &&
      _consent.complete;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb ||
        state != AppLifecycleState.resumed ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _loading ||
        _paying ||
        _recoveringPayment ||
        _pendingPayment ||
        _preparationRequiresRestart ||
        widget.testMode ||
        !_ownerCurrent) {
      return;
    }
    unawaited(_refresh(quoteOnly: true));
  }

  @override
  void dispose() {
    if (kIsWeb) WidgetsBinding.instance.removeObserver(this);
    for (final controller in [_name, _phone, _zip, _address, _detail, _memo]) {
      controller.dispose();
    }
    _scroll.dispose();
    _recoveryTimer?.cancel();
    super.dispose();
  }

  Future<bool> _refresh({bool quoteOnly = false}) async {
    if (_loading || !_ownerCurrent) return false;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(orderRepositoryProvider);
      final results = await Future.wait<Object>([
        if (!quoteOnly)
          repository.fetchPrintPreviewSnapshot(albumId: widget.albumId),
        repository.fetchPrintCheckoutReadiness(albumId: widget.albumId),
      ]);
      final readiness = results.last as PrintCheckoutReadiness;
      // Current readiness contains the server's reviewed content revision.
      // Older responses still require reading the snapshot for comparison.
      final snapshot = !quoteOnly
          ? results.first as Map<String, dynamic>
          : readiness.reviewedRevision == null
          ? await repository.fetchPrintPreviewSnapshot(albumId: widget.albumId)
          : null;
      final testCapability = widget.testMode
          ? await _testService.capability(
              albumId: widget.albumId,
              reviewedRevision: widget.reviewedRevision,
            )
          : null;
      final quote = readiness.quote;
      final changed =
          snapshot != null &&
              printCheckoutRevision(snapshot) != widget.reviewedRevision ||
          readiness.reviewedRevision != null &&
              readiness.reviewedRevision != widget.reviewedRevision ||
          quote.productCode != widget.initialQuote.productCode ||
          quote.pageCount != widget.initialQuote.pageCount ||
          quote.sourcePageCount != widget.initialQuote.sourcePageCount;
      final specChanged =
          printSpecRevision(quote.printSpec) !=
              printSpecRevision(widget.initialQuote.printSpec) ||
          readiness.reviewedSpecRevision != null &&
              readiness.reviewedSpecRevision !=
                  printSpecRevision(quote.printSpec);
      final priceChanged =
          quote.amount != _quote.amount ||
          quote.pricePolicyVersion != _quote.pricePolicyVersion ||
          quote.shippingIncluded != _quote.shippingIncluded ||
          quote.retailPriceStatus != _quote.retailPriceStatus;
      if (!mounted || !_ownerCurrent) return false;
      setState(() {
        _quote = quote;
        _readiness = readiness;
        _testCapability = testCapability;
        _reviewChanged = changed || specChanged;
        if (changed || specChanged || priceChanged) _clearConsent();
        _notice = changed || specChanged
            ? '앨범 내용이나 제작 구성이 바뀌었어요. 인쇄 미리보기를 다시 확인해주세요.'
            : priceChanged
            ? '제작 금액이 갱신되었습니다. 새 금액을 확인해주세요.'
            : null;
      });
      _revealOrderNotice();
      return true;
    } catch (_) {
      if (mounted && _ownerCurrent) {
        setState(() {
          _readiness = null;
          _testCapability = null;
          _error = '주문 준비 상태를 확인하지 못했습니다. 다시 확인해주세요.';
        });
        _revealOrderNotice();
      }
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _deliveryChanged(String _) {
    if (_consent.orderReviewed ||
        _policyAccepted ||
        _customProductionAccepted) {
      setState(_clearConsent);
    }
  }

  Future<void> _searchAddress() async {
    if (_paying || _deliveryLocked || !_ownerCurrent) return;
    final selected = kIsWeb
        ? await showWebAwareDialog<AddressSearchItem>(
            context: context,
            maxWidth: 820,
            maxHeight: 760,
            builder: (_) => const _AddressSearchSheet(),
          )
        : await showModalBottomSheet<AddressSearchItem>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: SnapFitColors.backgroundOf(context),
            constraints: const BoxConstraints(maxWidth: 640),
            builder: (_) => const _AddressSearchSheet(),
          );
    if (!mounted || !_ownerCurrent || selected == null) return;
    setState(() {
      _zip.text = selected.zipCode;
      _address.text = selected.roadAddressPart1.isNotEmpty
          ? selected.roadAddressPart1
          : selected.roadAddress;
      _clearConsent();
    });
  }

  Future<void> _review() async {
    FocusScope.of(context).unfocus();
    if (!_ownerCurrent || _loading || _paying) return;
    if (kIsWeb) {
      final invalidFields = _formKey.currentState!.validateGranularly();
      if (invalidFields.isNotEmpty) {
        final firstInvalid = invalidFields.first;
        // Error labels change field heights. Reveal the first existing
        // validator error after the updated web form has finished layout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_ownerCurrent || !firstInvalid.mounted || _reviewing)
            return;
          unawaited(
            Scrollable.ensureVisible(
              firstInvalid.context,
              alignment: .25,
              duration: const Duration(milliseconds: 180),
              alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
            ),
          );
        });
        return;
      }
    } else if (!_formKey.currentState!.validate()) {
      return;
    }
    final refreshed = await _refresh();
    if (!mounted || !_ownerCurrent || !refreshed || _reviewChanged) return;
    setState(() => _reviewing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ownerCurrent && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _pay() async {
    if (widget.testMode) return _payTest();
    if (!_canPay) return;
    var recoverPreparation = false;
    setState(() {
      _paying = true;
      _preparationNotice = null;
    });
    try {
      // Re-read server state before opening a payment provider.
      if (!await _refresh() ||
          !mounted ||
          !_ownerCurrent ||
          !_canPayIgnoringBusy)
        return;
      final request = PrintCheckoutRequest(
        albumId: widget.albumId,
        reviewedRevision: widget.reviewedRevision,
        reviewedSpecRevision: printSpecRevision(widget.initialQuote.printSpec),
        amount: _quote.amount,
        recipientName: _name.text.trim(),
        recipientPhone: _phone.text.replaceAll(RegExp(r'\D'), ''),
        zipCode: _zip.text.trim(),
        addressLine1: _address.text.trim(),
        addressLine2: _detail.text.trim(),
        deliveryMemo: _memo.text.trim(),
        consent: _consent,
      );
      PrintPaidReceipt? receipt;
      if (widget.onPay != null) {
        receipt = await widget.onPay!(request);
      } else {
        final outcome = await ref
            .read(printPaymentServiceProvider)
            .pay(
              request,
              (sdk) async {
                if (!mounted || !_ownerCurrent)
                  throw StateError('checkout_closed');
                final redirect = kIsWeb && sdk.redirectUrl == null
                    ? sdk.withReturnUrl(
                        Uri.base.replace(
                          path: '/payment-return',
                          query: '',
                          fragment: '',
                        ),
                      )
                    : sdk;
                return ref.read(portOnePaymentLauncherProvider)(
                  context,
                  redirect,
                );
              },
              onProgress: (message) {
                if (mounted && _ownerCurrent)
                  setState(() => _fileProgress = message);
              },
            );
        if (!mounted || !_ownerCurrent) return;
        final pending = outcome.pending
            ? await ref.read(printPaymentServiceProvider).pending()
            : null;
        if (!mounted || !_ownerCurrent) return;
        recoverPreparation = outcome.pending && pending?.sdkStarted == false;
        setState(() {
          _pendingPayment = outcome.pending;
          _pendingCanResume = false;
          if (pending != null) {
            _pendingSdkStarted = pending.sdkStarted;
            _pendingOrderId = pending.orderId;
            _pendingTarget = pending.paymentId != null
                ? PrintOrderRequestTarget.payment(pending.paymentId!)
                : PrintOrderRequestTarget.checkout(pending.requestId);
          }
          _notice = outcome.noCharge
              ? '결제가 완료되지 않았거나 취소됐습니다. 내용을 확인한 뒤 다시 결제할 수 있어요.'
              : null;
          _preparationNotice =
              outcome.preparationError == 'print_checkout_pdf_too_large'
              ? '인쇄 파일이 제작 가능한 용량을 넘었어요. 표지는 최대 150MB, 내지는 최대 500MB이며 결제창은 열지 않았습니다. 준비 주문을 취소한 뒤 앨범 구성을 조정해 새 주문을 준비해주세요.'
              : outcome.preparationError == 'print_package_partial_upload'
              ? '원본 파일 일부의 업로드가 완료되지 않았어요. 결제창은 열지 않았습니다. 아래에서 준비 주문을 취소한 뒤 같은 앨범으로 다시 준비해주세요.'
              : outcome.preparationError != null
              ? '인쇄 파일 업로드·검수를 완료하지 못했어요. 결제창은 열지 않았습니다. 같은 주문으로 준비를 다시 시도해주세요.'
              : null;
          _preparationRequiresRestart = {
            'print_checkout_pdf_too_large',
            'print_package_partial_upload',
          }.contains(outcome.preparationError);
        });
        receipt = outcome.receipt;
        _scheduleRecovery();
      }
      if (!mounted || !_ownerCurrent || receipt == null) return;
      if (!receipt.isValid ||
          receipt.albumId != widget.albumId ||
          receipt.amount != _quote.amount) {
        throw StateError('payment_receipt_unverified');
      }
      final verifiedReceipt = await ref
          .read(orderRepositoryProvider)
          .fetchPrintPaidReceipt(
            orderId: receipt.orderId,
            albumId: widget.albumId,
            expectedAmount: _quote.amount,
          );
      if (!mounted || !_ownerCurrent) return;
      ref.invalidate(myOrderHistoryProvider);
      ref.invalidate(myOrderSummaryProvider);
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => PrintOrderCompleteScreen(receipt: verifiedReceipt),
        ),
      );
    } catch (_) {
      if (mounted && _ownerCurrent) {
        setState(() => _error = '결제 결과를 확인하지 못했습니다. 결제 결과를 다시 확인해주세요.');
      }
    } finally {
      if (mounted)
        setState(() {
          _paying = false;
          _fileProgress = null;
        });
      if (mounted) _revealOrderNotice();
      // Restore the frozen invoice immediately after an interrupted upload.
      // Otherwise the disabled payment button leaves no way to retry on this
      // visit, even though the SDK has never opened.
      if (mounted && recoverPreparation) await _recoverPayment();
    }
  }

  bool get _canPayIgnoringBusy =>
      _ownerCurrent &&
      !_pendingCustomerRequestHold &&
      !_preparationRequiresRestart &&
      !_reviewChanged &&
      _error == null &&
      _paymentAvailable &&
      _quote.hasPlannedRetailPrice &&
      _consent.complete;

  Future<void> _payTest() async {
    if (!_canPay) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      if (!await _refresh() ||
          !mounted ||
          !_ownerCurrent ||
          !_canPayIgnoringBusy)
        return;
      final current =
          _testSession ??
          await _testService.prepare(
            albumId: widget.albumId,
            reviewedRevision: widget.reviewedRevision,
            recipient: {
              'name': _name.text.trim(),
              'phone': _phone.text.replaceAll(RegExp(r'\D'), ''),
              'zipCode': _zip.text.trim(),
              'addressLine1': _address.text.trim(),
              'addressLine2': _detail.text.trim(),
              'deliveryMemo': _memo.text.trim(),
            },
          );
      if (!mounted || !_ownerCurrent) return;
      _assertTestIdentity(current);
      setState(() => _testSession = current);
      final ready = await _testService.prepareFiles(
        current,
        onProgress: (message) {
          if (mounted && _ownerCurrent) setState(() => _fileProgress = message);
        },
      );
      if (!mounted || !_ownerCurrent) return;
      _assertTestIdentity(ready);
      setState(() => _testSession = ready);
      final authorized = await _testService.authorize(ready);
      if (!mounted || !_ownerCurrent) return;
      _assertTestIdentity(authorized);
      setState(() {
        _testSession = authorized;
        _testSdkStarted = true;
        _fileProgress = '포트원 TEST 결제창을 여는 중';
      });
      var sdk = authorized.sdkRequest;
      if (sdk == null) throw const FormatException('print_dev_sdk_invalid');
      if (kIsWeb && sdk.redirectUrl == null) {
        sdk = sdk.withReturnUrl(
          Uri.base.replace(path: '/', query: '', fragment: ''),
        );
      }
      await _testService.assertCanLaunch(authorized);
      if (!mounted || !_ownerCurrent) return;
      await ref.read(portOnePaymentLauncherProvider)(context, sdk);
      if (!mounted || !_ownerCurrent) return;
      // Only Cron reads the actual TEST receipt and places a DEV supplier
      // order. A successful, canceled or failed SDK callback proves neither.
      setState(() {
        _notice =
            '결제창 결과를 서버에서 확인하고 있어요. 이제 앱을 닫아도 TEST 결제 확인과 개발 주문 접수가 이어집니다. 실제 청구·제작·배송은 없습니다.';
        _clearConsent();
      });
    } catch (error) {
      if (mounted && _ownerCurrent) {
        setState(() {
          _testRecoveryUnknown = true;
          _error = _testError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _paying = false;
          _fileProgress = null;
        });
        _revealOrderNotice();
        _scheduleTestRecovery();
      }
    }
  }

  void _assertTestIdentity(PrintDevCheckoutSession session) {
    if (session.albumId != widget.albumId ||
        session.reviewedRevision != widget.reviewedRevision ||
        session.totalAmount != _quote.amount) {
      throw const FormatException('customer_print_test_identity_changed');
    }
  }

  Future<void> _recoverTestPayment() async {
    if (!mounted || !_ownerCurrent || _paying || _recoveringPayment) return;
    setState(() {
      _recoveringPayment = true;
      _testRecoveryUnknown = true;
    });
    try {
      final current = await _testService.resume();
      final started = await _testService.sdkStarted();
      if (!mounted || !_ownerCurrent) return;
      if (current != null) _assertTestIdentity(current);
      setState(() {
        _testSession = current;
        _testSdkStarted = started || current?.data['sdkIssuedAt'] != null;
        _testRecoveryUnknown = false;
        _error = null;
        if (current != null) {
          final recipient = current.data['recipient'];
          if (recipient is Map) {
            _name.text = '${recipient['name'] ?? ''}';
            _phone.text = '${recipient['phone'] ?? ''}';
            _zip.text = '${recipient['zipCode'] ?? ''}';
            _address.text = '${recipient['addressLine1'] ?? ''}';
            _detail.text = '${recipient['addressLine2'] ?? ''}';
            _memo.text = '${recipient['deliveryMemo'] ?? ''}';
          }
          _reviewing = true;
          _clearConsent();
        }
      });
    } catch (error) {
      if (mounted && _ownerCurrent) {
        setState(() {
          // Unknown ownership or recovery state never exposes an old address
          // or opens another payment window.
          for (final field in [_name, _phone, _zip, _address, _detail, _memo]) {
            field.clear();
          }
          _testSession = null;
          _testRecoveryUnknown = true;
          _error = _testError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _recoveringPayment = false);
      _scheduleTestRecovery();
    }
  }

  void _scheduleTestRecovery() {
    _recoveryTimer?.cancel();
    if (mounted &&
        _ownerCurrent &&
        widget.testMode &&
        (_testSdkStarted || _testRecoveryUnknown) &&
        !_testFileChecked) {
      _recoveryTimer = Timer(const Duration(seconds: 20), _recoverTestPayment);
    }
  }

  String _testError(Object error) {
    final code = error is PrintDevCheckoutException
        ? error.code
        : error is FormatException
        ? error.message
        : null;
    final reference = printDevErrorReference(code);
    const message =
        'TEST 주문 상태를 확인하지 못했어요. 기존 주문을 보존하며 결제 완료로 처리하지 않습니다. 다시 확인해주세요.';
    return reference == null ? message : '$message\n참조 코드: $reference';
  }

  Future<void> _recoverPayment() async {
    if (_paying || _recoveringPayment || !mounted || !_ownerCurrent) return;
    setState(() => _recoveringPayment = true);
    try {
      final service = ref.read(printPaymentServiceProvider);
      final stored = await service.pending();
      if (stored == null) {
        if (mounted && _ownerCurrent)
          setState(() {
            _pendingPayment = false;
            _pendingCanResume = false;
            _pendingTarget = null;
            _pendingCustomerRequestHold = false;
            _pendingOrderId = null;
            _notice = null;
            _preparationNotice = null;
            _preparationRequiresRestart = false;
          });
        return;
      }
      if (mounted && _ownerCurrent) setState(() => _pendingPayment = true);
      if (mounted && _ownerCurrent)
        setState(() {
          _pendingSdkStarted = stored.sdkStarted;
          _pendingOrderId = stored.orderId;
          _pendingCanResume = false;
          _pendingTarget = stored.paymentId != null
              ? PrintOrderRequestTarget.payment(stored.paymentId!)
              : PrintOrderRequestTarget.checkout(stored.requestId);
        });
      final result = await service.recover();
      if (!mounted || !_ownerCurrent) return;
      setState(() {
        _pendingPayment = result.pending;
        if (!result.pending) {
          _pendingCanResume = false;
          _pendingCustomerRequestHold = false;
          _pendingTarget = null;
          _pendingOrderId = null;
          _notice = result.noCharge
              ? '결제가 완료되지 않았거나 취소됐습니다. 내용을 확인한 뒤 다시 결제할 수 있어요.'
              : null;
        } else if (stored.sdkStarted) {
          _notice = result.verificationUnavailable
              ? '결제 서비스에 연결하지 못했어요. 기존 주문번호로 다시 확인하며 중복 결제는 진행하지 않습니다.'
              : null;
        }
      });
      if (result.pending && !stored.sdkStarted) {
        PrintPaymentInvoice? invoice;
        var missingPlaceholder = false;
        try {
          invoice = await service.pendingInvoice();
        } on PrintCheckoutApiException catch (error) {
          missingPlaceholder =
              error.statusCode == 404 &&
              error.reasonCode == 'print_checkout_not_found' &&
              stored.paymentId == null &&
              stored.orderId == null &&
              stored.albumId == widget.albumId &&
              stored.amount == _quote.amount;
          if (!missingPlaceholder) rethrow;
        }
        if (!mounted || !_ownerCurrent) return;
        if (invoice?.customerRequestHold == true) {
          setState(() {
            _pendingCustomerRequestHold = true;
            _pendingCanResume = false;
            _clearConsent();
          });
        } else if (missingPlaceholder) {
          setState(() {
            _pendingCustomerRequestHold = false;
            _pendingCanResume = true;
            _clearConsent();
            _notice = '주문 준비 응답을 아직 확인하지 못했어요. 내용을 확인하면 같은 주문번호로 준비를 다시 시도합니다.';
          });
        } else if (invoice != null &&
            invoice.albumId == widget.albumId &&
            invoice.totalAmount == _quote.amount &&
            invoice.reviewedRevision == widget.reviewedRevision &&
            (invoice.reviewedSpecRevision == null ||
                invoice.reviewedSpecRevision ==
                    printSpecRevision(widget.initialQuote.printSpec)) &&
            invoice.recipient.isNotEmpty) {
          final restoredInvoice = invoice;
          final recipient = restoredInvoice.recipient;
          setState(() {
            _pendingCustomerRequestHold = false;
            _pendingOrderId = restoredInvoice.orderId;
            _pendingTarget = PrintOrderRequestTarget.payment(
              restoredInvoice.paymentId,
            );
            _name.text = '${recipient['name'] ?? ''}';
            _phone.text = '${recipient['phone'] ?? ''}';
            _zip.text = '${recipient['zipCode'] ?? ''}';
            _address.text = '${recipient['addressLine1'] ?? ''}';
            _detail.text = '${recipient['addressLine2'] ?? ''}';
            _memo.text = '${recipient['deliveryMemo'] ?? ''}';
            _pendingCanResume = true;
            _reviewing = true;
            _clearConsent();
            _notice =
                '이전에 준비한 주문을 불러왔어요. 배송지와 앨범 내용을 확인하면 같은 주문으로 결제를 이어갈 수 있어요.';
          });
        } else {
          setState(
            () => _notice =
                '이전에 준비한 주문과 현재 앨범·금액이 달라요. 기존 주문을 확인하거나 취소를 요청한 뒤 새 주문을 준비해주세요.',
          );
        }
      }
      if (result.receipt != null) {
        ref.invalidate(myOrderHistoryProvider);
        ref.invalidate(myOrderSummaryProvider);
        await Navigator.pushReplacement<void, void>(
          context,
          MaterialPageRoute(
            builder: (_) => PrintOrderCompleteScreen(receipt: result.receipt!),
          ),
        );
      }
    } catch (_) {
      // Unknown stored state keeps the new-charge gate closed.
      if (mounted && _ownerCurrent)
        setState(() {
          _pendingPayment = true;
          _pendingCanResume = false;
          _notice =
              '기존 주문 상태를 불러오지 못했어요. 다시 확인하거나 주문 내역에서 진행 상황을 확인해주세요. 확인 전에는 새 결제를 진행하지 않습니다.';
        });
    } finally {
      if (mounted) setState(() => _recoveringPayment = false);
      _scheduleRecovery();
    }
  }

  void _scheduleRecovery() {
    _recoveryTimer?.cancel();
    if (mounted &&
        _ownerCurrent &&
        _pendingPayment &&
        !_pendingCanResume &&
        _pendingSdkStarted) {
      _recoveryTimer = Timer(const Duration(seconds: 20), _recoverPayment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOwner = ref.watch(visibleOrderOwnerProvider);
    if (currentOwner != null && _ownerId == null) {
      _ownerId = currentOwner;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ownerCurrent) return;
        _refresh();
        if (widget.testMode) {
          _recoverTestPayment();
        } else if (widget.onPay == null) {
          _recoverPayment();
        }
      });
    }
    if (currentOwner == null || currentOwner != _ownerId) {
      if (kIsWeb) {
        return SnapFitWebShell(
          title: '앨범 주문',
          showNavigation: false,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('앨범으로 돌아가기'),
            ),
          ],
          child: ListView(
            children: [
              const WebPageHeading(
                eyebrow: '앨범  /  인쇄 주문',
                title: '로그인 계정을 확인해주세요',
              ),
              const SizedBox(height: 24),
              WebSurface(
                child: Text(
                  currentOwner == null
                      ? '로그인한 계정을 확인한 뒤 앨범을 주문할 수 있어요.'
                      : '로그인 계정이 변경되었어요. 이 화면을 닫고 앨범 주문을 다시 열어주세요.',
                ),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: const ExperienceHeader(
          title: '앨범 주문',
          showNotifications: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              currentOwner == null
                  ? '로그인한 계정을 확인한 뒤 앨범을 주문할 수 있어요.'
                  : '로그인 계정이 변경되었어요. 이 화면을 닫고 앨범 주문을 다시 열어주세요.',
              style: ExperienceFormStyle.text(context, 14),
            ),
          ),
        ),
      );
    }
    return PopScope<String>(
      canPop: !_paying && !_reviewing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_paying && _reviewing) {
          setState(() => _reviewing = false);
        }
      },
      child: kIsWeb
          ? _webCheckout()
          : Scaffold(
              backgroundColor: SnapFitColors.backgroundOf(context),
              appBar: ExperienceHeader(
                title: _reviewing ? '주문 내용 확인' : '배송지 입력',
                showNotifications: false,
                onBack: _paying
                    ? () {}
                    : () {
                        if (_reviewing) {
                          setState(() => _reviewing = false);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                actions: [
                  IconButton(
                    onPressed: _loading || _paying ? null : _refresh,
                    tooltip: '최신 주문 정보 확인',
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final wide =
                        bounds.maxWidth >= 540 &&
                        MediaQuery.orientationOf(context) ==
                            Orientation.landscape;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? 1040 : 640,
                        ),
                        child: wide
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: (bounds.maxWidth * .33).clamp(
                                        180,
                                        280,
                                      ),
                                      child: SingleChildScrollView(
                                        key: const PageStorageKey(
                                          'print-checkout-summary',
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _albumSummary(compact: true),
                                            const SizedBox(height: 8),
                                            _priceDetails(compact: true),
                                            const SizedBox(height: 16),
                                            Divider(
                                              color: ExperienceFormStyle.line(
                                                context,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _configuration(
                                              includeProduct: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    VerticalDivider(
                                      width: 1,
                                      color: ExperienceFormStyle.line(context),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: _checkoutContent(wide: true),
                                    ),
                                  ],
                                ),
                              )
                            : _checkoutContent(wide: false),
                      ),
                    );
                  },
                ),
              ),
              bottomNavigationBar: _reviewing
                  ? SafeArea(
                      top: false,
                      child: LayoutBuilder(
                        builder: (context, bounds) {
                          final wide =
                              bounds.maxWidth >= 540 &&
                              MediaQuery.orientationOf(context) ==
                                  Orientation.landscape;
                          return Align(
                            heightFactor: 1,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: wide ? 1040 : 640,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: wide ? 20 : 24,
                                  vertical: wide ? 8 : 12,
                                ),
                                child: _paymentActions(wide: wide),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : null,
            ),
    );
  }

  void _webBack() {
    if (_paying) return;
    if (_reviewing) {
      setState(() => _reviewing = false);
    } else {
      Navigator.pop(context);
    }
  }

  Widget _webCheckout() => SnapFitWebShell(
    title: '앨범 주문',
    section: WebSection.orders,
    showNavigation: false,
    actions: [
      TextButton.icon(
        onPressed: _paying ? null : _webBack,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: Text(_reviewing ? '배송지 수정' : '이전'),
      ),
      IconButton(
        onPressed: _loading || _paying ? null : _refresh,
        tooltip: '최신 주문 정보 확인',
        icon: const Icon(Icons.refresh, size: 20),
      ),
    ],
    child: ListView(
      key: const PageStorageKey('print-checkout-content'),
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        WebPageHeading(
          title: _reviewing ? '주문 확인' : '배송지 입력',
          description: _reviewing
              ? '앨범 사양, 배송지와 최종 금액을 확인하세요.'
              : '책을 받을 분과 배송지 정보를 입력하세요.',
          trailing: widget.testMode
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: WebPalette.of(context).softBrand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TEST · 실제 청구 없음',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WebPalette.of(context).brandInk,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 20),
        _steps(),
        const SizedBox(height: 24),
        CustomerWebColumns(
          breakpoint: 980,
          summaryWidth: 350,
          primary: WebSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._orderNotices(),
                _heading(_reviewing ? '배송 정보' : '받는 분과 주소'),
                const SizedBox(height: 24),
                if (_reviewing) _reviewDetails(wide: true) else _deliveryForm(),
              ],
            ),
          ),
          secondary: WebSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '주문 요약',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: WebPalette.of(context).ink,
                  ),
                ),
                const SizedBox(height: 18),
                _albumSummary(compact: true),
                const SizedBox(height: 24),
                Divider(color: WebPalette.of(context).line),
                const SizedBox(height: 18),
                _configuration(includeProduct: true),
                const SizedBox(height: 24),
                Divider(color: WebPalette.of(context).line),
                const SizedBox(height: 18),
                _priceDetails(compact: true),
                const SizedBox(height: 24),
                if (_reviewing)
                  _paymentActions(wide: false)
                else ...[
                  Icon(
                    Icons.local_shipping_outlined,
                    color: WebPalette.of(context).brandInk,
                    size: 24,
                  ),
                  _note(
                    '배송지 입력 후 주문 내용을 확인합니다. 결제 가능 여부와 최종 금액은 주문 확인 단계에서 안내합니다.',
                  ),
                ],
                const SizedBox(height: 16),
                _note(
                  widget.testMode
                      ? 'TEST 결제와 개발 주문만 진행합니다. 실제 책은 제작·배송되지 않습니다.'
                      : '결제 전에 인쇄 파일을 준비합니다. 결제 확인 후에는 창을 닫아도 주문 처리가 이어집니다.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );

  Widget _checkoutContent({required bool wide}) => ListView(
    key: const PageStorageKey('print-checkout-content'),
    controller: _scroll,
    padding: wide
        ? const EdgeInsets.symmetric(vertical: 16)
        : const EdgeInsets.fromLTRB(24, 20, 24, 28),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: [
      _steps(),
      if (!wide) ...[const SizedBox(height: 24), _albumSummary()],
      ..._orderNotices(),
      const SizedBox(height: 24),
      if (_reviewing) _reviewDetails(wide: wide) else _deliveryForm(),
    ],
  );

  Widget _albumSummary({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!compact) ...[
        Text(
          '제작할 앨범',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        const SizedBox(height: 6),
      ],
      Text(
        widget.albumTitle,
        maxLines: compact ? 2 : null,
        overflow: compact ? TextOverflow.ellipsis : null,
        style: ExperienceFormStyle.text(
          context,
          compact ? 16 : 24,
          weight: compact ? FontWeight.w600 : FontWeight.w700,
        ),
      ),
      if (!compact) ...[
        const SizedBox(height: 6),
        Text(
          '${_productLabel()} · 내지 ${_quote.pageCount}페이지 · 1권',
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
      ],
    ],
  );

  List<Widget> _orderNotices() => [
    if (widget.testMode) ...[
      const SizedBox(height: 16),
      _message('TEST 주문 · 실제 청구·제작·배송 없음'),
      _note('일반 주문과 같은 배송지·주문 확인 화면에서 개발 테스트를 진행합니다. 정식 결제는 열리지 않습니다.'),
      if (_testSession != null) ...[
        const SizedBox(height: 12),
        _testOrderStatus(),
      ],
      if (_testSession != null || _testRecoveryUnknown)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('print-test-status-refresh'),
            onPressed: _paying || _recoveringPayment
                ? null
                : _recoverTestPayment,
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text('TEST 주문 상태 확인'),
          ),
        ),
      if (_testSession != null && widget.onOpenTestOrder != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('print-test-order-history'),
            onPressed: _paying
                ? null
                : () => widget.onOpenTestOrder!(_testSession!.runId),
            child: const Text('주문내역에서 TEST 주문 확인'),
          ),
        ),
    ],
    if (_fileProgress != null) ...[
      const SizedBox(height: 20),
      const LinearProgressIndicator(),
      _note(_fileProgress!),
      _note('파일 준비가 끝날 때까지 앱을 열어두세요. 업로드·검수가 완료된 뒤 결제창이 열립니다.'),
    ],
    if (_loading) ...[
      const SizedBox(height: 20),
      const LinearProgressIndicator(),
      _note('최신 앨범과 제작 금액을 확인하는 중'),
    ],
    if (_error != null) ...[
      const SizedBox(height: 16),
      _message(_error!),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _loading || _paying ? null : _refresh,
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('다시 확인'),
        ),
      ),
    ],
    if (_notice != null) ...[const SizedBox(height: 16), _message(_notice!)],
    if (_preparationNotice != null) ...[
      const SizedBox(height: 16),
      _message(_preparationNotice!),
    ],
    if (_pendingPayment) ...[
      const SizedBox(height: 16),
      _message(
        _pendingCustomerRequestHold
            ? '취소·환불 요청을 처리하고 있어요. 기존 주문을 유지하며 상태를 확인하고, 결과가 확정되기 전에는 결제창을 다시 열지 않습니다.'
            : _pendingCanResume
            ? '준비한 주문의 배송지와 금액을 확인한 뒤 결제를 이어가세요.'
            : !_pendingSdkStarted
            ? '결제창을 아직 열지 않은 준비 주문이 있어요. 같은 주문을 확인하거나 취소 요청으로 준비를 정리할 수 있습니다.'
            : '이전 결제 결과를 확인하고 있어요. 중복 결제를 막기 위해 결과 확인이 끝난 뒤 다음 결제를 진행합니다.',
      ),
      if (_deliveryLocked)
        _note(
          '이 주문의 배송지는 확정되어 있어요. 배송지나 앨범을 바꾸려면 기존 주문의 취소 결과를 확인한 뒤 새 주문을 준비해주세요.',
        ),
      if (_pendingTarget != null)
        TextButton.icon(
          onPressed: _paying || _recoveringPayment
              ? null
              : () async {
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrintOrderRequestScreen(
                        target: _pendingTarget!,
                        albumTitle: _pendingCanResume
                            ? widget.albumTitle
                            : null,
                        albumId: _pendingCanResume ? widget.albumId : null,
                        initialType: 'CANCEL',
                        initialReason: !_pendingSdkStarted
                            ? '인쇄 파일을 다시 준비하기 위해 기존 주문 취소를 요청합니다.'
                            : null,
                        returnToAlbumEditing: !_pendingSdkStarted,
                      ),
                    ),
                  );
                  if (!mounted || !_ownerCurrent) return;
                  await _recoverPayment();
                  if (!mounted || !_ownerCurrent) return;
                  if (result == 'request_resolved' ||
                      result == 'preparation_aborted') {
                    setState(_clearConsent);
                  }
                  if (result == 'preparation_aborted' && !_pendingPayment) {
                    Navigator.pop(context, 'edit_album');
                  }
                },
          icon: const Icon(Icons.help_outline),
          label: Text(_pendingSdkStarted ? '기존 주문 취소 · 환불 문의' : '준비 주문 취소 요청'),
        ),
      OutlinedButton.icon(
        onPressed: _paying || _recoveringPayment ? null : _recoverPayment,
        icon: const Icon(Icons.refresh),
        label: const Text('결제 결과 다시 확인'),
      ),
      if (_pendingOrderId != null)
        TextButton(
          onPressed: _paying
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderHistoryScreen(initialOrderId: _pendingOrderId),
                  ),
                ),
          child: const Text('이전 주문 확인하기'),
        ),
    ],
    if (_reviewChanged)
      TextButton.icon(
        onPressed: _paying
            ? null
            : () => Navigator.pop(context, 'review_again'),
        icon: const Icon(Icons.menu_book_outlined, size: 18),
        label: const Text('인쇄 미리보기 다시 확인'),
      ),
  ];

  Widget _testOrderStatus() {
    final session = _testSession!;
    final status = switch (session.verifiedTest ? session.stage : '') {
      'FILE_CHECKED' when session.devOrderNum != null =>
        '레드프린팅 개발 주문 · 파일 확인 완료',
      'ACCEPTED' => '레드프린팅 개발 주문 접수 · 파일 확인 중',
      'SUBMITTING' || 'UNKNOWN' => '레드프린팅 개발 주문 접수 여부 확인 중',
      'PAYMENT_VERIFIED' => 'TEST 결제 확인 완료 · 개발 주문 접수 대기',
      _ =>
        session.verifiedTest
            ? 'TEST 결제 확인 완료 · 개발 주문 처리 중'
            : _testSdkStarted
            ? '서버에서 TEST 결제 결과 확인 중'
            : session.filesReady
            ? '인쇄 파일 검수 완료 · TEST 결제 대기'
            : '인쇄 파일 준비 대기',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(status),
        _note(
          session.verifiedTest
              ? '서버에서 포트원 TEST 승인 내역을 확인했습니다.'
              : '서버가 승인 내역을 확인하기 전에는 결제 완료로 표시하지 않습니다.',
        ),
        _note('주문번호 ${session.orderId}'),
        if (_testSdkStarted) _note('앱을 닫아도 서버에서 결제 확인과 개발 주문 처리가 이어집니다.'),
      ],
    );
  }

  Widget _steps() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      _step('1', '배송지', !_reviewing),
      const Icon(Icons.chevron_right, size: 18),
      _step('2', '주문 확인', _reviewing),
    ],
  );

  Widget _step(String number, String label, bool selected) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: selected
            ? ExperienceFormStyle.selection(context)
            : ExperienceFormStyle.surface(context),
        child: Text(number, style: ExperienceFormStyle.text(context, 12)),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: ExperienceFormStyle.text(
          context,
          13,
          weight: selected ? FontWeight.w600 : FontWeight.w400,
          secondary: !selected,
        ),
      ),
    ],
  );

  Widget _deliveryForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          label: '받는 분',
          key: const ValueKey('print-recipient-name'),
          controller: _name,
          maxLength: 40,
          autofillHints: const [AutofillHints.name],
          validator: (v) =>
              (v?.trim().isEmpty ?? true) ? '받는 분 이름을 입력해주세요.' : null,
        ),
        _field(
          label: '휴대폰 번호',
          key: const ValueKey('print-recipient-phone'),
          controller: _phone,
          hint: '01012345678',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.telephoneNumberNational],
          validator: (v) => RegExp(r'^010\d{8}$').hasMatch(v?.trim() ?? '')
              ? null
              : '010으로 시작하는 휴대폰 번호 11자리를 입력해주세요.',
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '배송 주소',
                style: ExperienceFormStyle.text(
                  context,
                  14,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _paying || _deliveryLocked ? null : _searchAddress,
              icon: const Icon(Icons.search, size: 17),
              label: const Text('주소 검색'),
            ),
          ],
        ),
        _note('검색이 어려우면 우편번호와 도로명 주소를 직접 입력해주세요.'),
        const SizedBox(height: 12),
        _field(
          label: '우편번호',
          key: const ValueKey('print-zip-code'),
          controller: _zip,
          hint: '5자리 우편번호',
          keyboardType: TextInputType.number,
          maxLength: 5,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.postalCode],
          validator: (v) => RegExp(r'^\d{5}$').hasMatch(v?.trim() ?? '')
              ? null
              : '우편번호 5자리를 입력해주세요.',
        ),
        _field(
          label: '도로명 주소',
          key: const ValueKey('print-address-line1'),
          controller: _address,
          maxLength: 150,
          autofillHints: const [AutofillHints.streetAddressLine1],
          validator: (v) =>
              (v?.trim().isEmpty ?? true) ? '도로명 주소를 입력해주세요.' : null,
        ),
        _field(
          label: '상세 주소',
          key: const ValueKey('print-address-line2'),
          controller: _detail,
          hint: '동·호수 등',
          maxLength: 100,
          autofillHints: const [AutofillHints.streetAddressLine2],
        ),
        _field(
          label: '배송 요청 사항 (선택)',
          key: const ValueKey('print-delivery-memo'),
          controller: _memo,
          hint: '배송 기사님께 전할 내용을 입력해주세요.',
          maxLength: 100,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading || _paying || _reviewChanged ? null : _review,
            style: ExperienceFormStyle.primary(context),
            child: const Text('주문 내용 확인하기'),
          ),
        ),
        _note('배송지는 주문 요청 시 제작과 배송에 필요한 정보로 전달됩니다.'),
      ],
    ),
  );

  Widget _field({
    required String label,
    required Key key,
    required TextEditingController controller,
    String? hint,
    int? maxLength,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: key,
          controller: controller,
          enabled: !_paying && !_deliveryLocked,
          style: ExperienceFormStyle.text(context, 14),
          decoration: ExperienceFormStyle.input(
            context,
            hint: hint,
          ).copyWith(counterText: ''),
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          validator: validator,
          onChanged: _deliveryChanged,
        ),
      ],
    ),
  );

  Widget _reviewDetails({required bool wide}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: _heading('받는 곳')),
          TextButton(
            onPressed: _paying || _deliveryLocked
                ? null
                : () => setState(() => _reviewing = false),
            child: const Text('수정'),
          ),
        ],
      ),
      Text(
        '${_name.text.trim()} · ${_phone.text}',
        style: ExperienceFormStyle.text(context, 14),
      ),
      const SizedBox(height: 6),
      Text(
        '[${_zip.text}] ${_address.text.trim()}\n${_detail.text.trim()}',
        style: ExperienceFormStyle.text(context, 14),
      ),
      if (_memo.text.trim().isNotEmpty) _note(_memo.text.trim()),
      if (!wide) ...[
        const SizedBox(height: 24),
        Divider(color: ExperienceFormStyle.line(context)),
        const SizedBox(height: 16),
        _configuration(),
        const SizedBox(height: 24),
        _priceDetails(),
      ],
      const SizedBox(height: 16),
      CheckboxListTile(
        key: const ValueKey('print-checkout-agreement'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _agreed,
        onChanged: _paying || _loading || _reviewChanged
            ? null
            : (v) => setState(() => _agreed = v == true),
        title: Text(
          PrintCheckoutConsent.reviewNotice,
          style: ExperienceFormStyle.text(context, 13),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton(
            onPressed: _paying
                ? null
                : () => Navigator.pop(context, 'review_again'),
            child: const Text('최종 인쇄 미리보기 다시 확인'),
          ),
          _policyLink('이용약관', TermsPolicyDocType.terms),
          _policyLink('취소·환불 정책', TermsPolicyDocType.refund),
          _policyLink('제작·배송 안내', TermsPolicyDocType.shipping),
          _policyLink('개인정보 처리방침', TermsPolicyDocType.privacy),
        ],
      ),
      CheckboxListTile(
        key: const ValueKey('print-checkout-policy-agreement'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _policyAccepted,
        onChanged: _paying || _loading || _reviewChanged
            ? null
            : (v) => setState(() => _policyAccepted = v == true),
        title: Text(
          '[필수] 이용약관과 취소·환불·제작·배송 정책을 확인하고 동의합니다.',
          style: ExperienceFormStyle.text(context, 13),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '주문제작 상품의 청약철회 안내',
        style: ExperienceFormStyle.text(context, 13, weight: FontWeight.w600),
      ),
      _note(CommercePolicy.customProductionConsent),
      CheckboxListTile(
        key: const ValueKey('print-checkout-custom-production-agreement'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _customProductionAccepted,
        onChanged: _paying || _loading || _reviewChanged
            ? null
            : (v) => setState(() => _customProductionAccepted = v == true),
        title: Text(
          '[필수·별도 동의] 위 주문제작 상품의 청약철회 제한 안내를 확인하고 동의합니다.',
          style: ExperienceFormStyle.text(context, 13),
        ),
      ),
      if (!widget.testMode && _readiness?.canPay != true)
        _note('현재 정책은 판매 준비용 초안입니다. 실제 결제와 제작 요청은 열리지 않습니다.'),
      const SizedBox(height: 8),
      if (widget.testMode && _testCapability == null) ...[
        _message('이 앨범의 TEST 주문 권한이나 제작 구성을 확인하지 못했어요.'),
        _note('서버가 허용한 앨범·구성에서만 TEST 결제창을 열 수 있습니다. 정식 결제는 열리지 않습니다.'),
        const SizedBox(height: 16),
      ] else if (!widget.testMode && _readiness?.canPay != true) ...[
        _message(
          _readiness?.message.isNotEmpty == true
              ? _readiness!.message
              : '정식 주문 서비스를 준비하고 있어요.',
        ),
        _note('현재 결제와 제작 요청은 접수되지 않습니다. 앨범은 계속 수정할 수 있어요.'),
        const SizedBox(height: 16),
      ],
      _note(
        '결제 전에 인쇄 PDF를 만들고 업로드·검수합니다. 파일 준비 중에는 앱을 열어두세요. 결제 완료 후에는 앱을 닫아도 주문 처리가 이어집니다.',
      ),
    ],
  );

  Widget _policyLink(String label, TermsPolicyDocType type) => TextButton(
    onPressed: _paying
        ? null
        : () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => TermsPolicyScreen(initialDocType: type),
            ),
          ),
    child: Text(label),
  );

  Widget _paymentActions({required bool wide}) {
    final payment = FilledButton(
      key: const ValueKey('print-checkout-payment'),
      onPressed: _canPay ? _pay : null,
      style: ExperienceFormStyle.primary(context),
      child: Text(
        widget.testMode
            ? _paying
                  ? _fileProgress != null
                        ? '인쇄 파일 준비 중'
                        : 'TEST 주문 준비 중'
                  : _testFileChecked
                  ? 'TEST 주문 · 파일 확인 완료'
                  : _testSdkStarted
                  ? 'TEST 주문 처리 중'
                  : _testRecoveryUnknown
                  ? '기존 TEST 주문 확인 필요'
                  : _testCapability != null
                  ? '${_won(_quote.amount)}원 TEST 결제하기'
                  : 'TEST 주문 확인 필요'
            : _paying
            ? _fileProgress != null
                  ? '인쇄 파일 준비 중'
                  : '결제 결과 확인 중'
            : _pendingPayment && !_pendingCanResume
            ? '결제 결과 확인 중'
            : _preparationRequiresRestart
            ? '준비 주문 취소 후 다시 준비'
            : _pendingCanResume
            ? '${_won(_quote.amount)}원 결제 이어하기'
            : _readiness?.canPay == true
            ? '${_won(_quote.amount)}원 결제하기'
            : '결제 준비 중',
      ),
    );
    final edit = OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        textStyle: ExperienceFormStyle.text(context, 14),
        shape: const StadiumBorder(),
      ),
      onPressed: _paying ? null : () => Navigator.pop(context, 'edit_album'),
      child: const Text('앨범 계속 편집하기'),
    );
    return wide
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: payment),
                const SizedBox(width: 12),
                Expanded(child: edit),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [payment, const SizedBox(height: 8), edit],
          );
  }

  Widget _configuration({bool includeProduct = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('제작 구성'),
      if (includeProduct) _note(_productLabel()),
      _note('표지와 내지 ${_quote.pageCount}페이지 · 1권'),
      _note(
        _quote.addedBlankPageCount > 0
            ? '작성한 내지 ${_quote.sourcePageCount}페이지 + 추가 빈 페이지 ${_quote.addedBlankPageCount}페이지'
            : '작성한 내지 ${_quote.sourcePageCount}페이지',
      ),
    ],
  );

  String get _priceHeading => widget.testMode
      ? 'TEST 결제금액'
      : kIsWeb
      ? (_quote.hasPlannedRetailPrice && !_quote.hasFinalRetailPrice
            ? '예정 판매가'
            : '판매가')
      : _readiness?.canPay == true
      ? '총 결제금액'
      : '예정 결제금액';

  Widget _priceDetails({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (compact || MediaQuery.textScalerOf(context).scale(24) > 32) ...[
        Text(
          _priceHeading,
          style: ExperienceFormStyle.text(
            context,
            compact ? 13 : 16,
            weight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        _priceAmount(),
      ] else
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _heading(_priceHeading)),
            _priceAmount(),
          ],
        ),
      if (_quote.hasPlannedRetailPrice && _quote.shippingIncluded)
        _note('기본 배송비 포함'),
      if (kIsWeb && _quote.hasPlannedRetailPrice) ...[
        _note('부가세 포함 · 1권 기준'),
        if (!_quote.shippingIncluded)
          _note('배송비가 확정되지 않았습니다. 배송비를 포함한 최종 금액 확인 전에는 결제할 수 없습니다.'),
        if (!_quote.hasFinalRetailPrice)
          _note('판매 준비 중인 예정 가격입니다. 정식 판매 전 가격·제작 조건이 변경될 수 있습니다.'),
      ],
      if (_quote.priceNotice.isNotEmpty)
        _note(_quote.priceNotice)
      else if (kIsWeb && !_quote.hasPlannedRetailPrice)
        _note('이 규격·페이지 조합의 제작비를 아직 확인하지 못했습니다. 비용 확인 후 판매가를 안내합니다.'),
    ],
  );

  Widget _priceAmount() => Text(
    _quote.hasPlannedRetailPrice
        ? '${_won(_quote.amount)}원'
        : kIsWeb
        ? '가격 확인 필요'
        : '견적 확인 중',
    style: ExperienceFormStyle.text(context, 24, weight: FontWeight.w700),
  );

  String _productLabel() {
    final product = PrintProduct.forId(_quote.productCode);
    return product?.label ?? _quote.productName;
  }

  Widget _heading(String text) => Text(
    text,
    style: ExperienceFormStyle.text(context, 16, weight: FontWeight.w600),
  );
  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: ExperienceFormStyle.text(context, 13, secondary: true),
    ),
  );
  Widget _message(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ExperienceFormStyle.surface(context),
      borderRadius: BorderRadius.circular(SnapFitRadius.lg),
    ),
    child: Text(text, style: ExperienceFormStyle.text(context, 14)),
  );
}

class _AddressSearchSheet extends ConsumerStatefulWidget {
  const _AddressSearchSheet();
  @override
  ConsumerState<_AddressSearchSheet> createState() =>
      _AddressSearchSheetState();
}

class _AddressSearchSheetState extends ConsumerState<_AddressSearchSheet> {
  final _keyword = TextEditingController();
  List<AddressSearchItem> _items = [];
  bool _busy = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy) return;
    if (_keyword.text.trim().length < 2) {
      setState(() => _error = '도로명이나 건물 이름을 2글자 이상 입력해주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(orderRepositoryProvider)
          .searchAddress(keyword: _keyword.text);
      if (mounted)
        setState(() {
          _items = result.items;
          _searched = true;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = '주소를 검색하지 못했습니다. 다시 검색하거나 배송지 화면에서 직접 입력해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: kIsWeb
          ? 1
          : MediaQuery.orientationOf(context) == Orientation.landscape
          ? .94
          : .85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '주소 검색',
                    style: ExperienceFormStyle.text(
                      context,
                      18,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('print-address-search-keyword'),
                    controller: _keyword,
                    style: ExperienceFormStyle.text(context, 14),
                    decoration: ExperienceFormStyle.input(
                      context,
                      hint: '도로명, 건물 이름',
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _search,
                  style: ExperienceFormStyle.primary(context),
                  child: const Text('검색'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const PageStorageKey('print-address-search-results'),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Text(_error!, style: ExperienceFormStyle.text(context, 13)),
                if (_searched && _items.isEmpty && !_busy && _error == null)
                  Text(
                    '검색 결과가 없어요. 도로명과 건물 번호로 다시 검색해주세요.',
                    style: ExperienceFormStyle.text(
                      context,
                      13,
                      secondary: true,
                    ),
                  ),
                for (final item in _items) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.roadAddress,
                      style: ExperienceFormStyle.text(context, 14),
                    ),
                    subtitle: Text(
                      item.zipCode,
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, item),
                  ),
                  Divider(color: ExperienceFormStyle.line(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _won(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);
