import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../profile/data/portone_payment_launcher.dart';
import '../../../profile/data/print_dev_checkout.dart';

/// An owned album follows the actual app renderer and TEST payment SDK. This
/// route never calls production checkout, payment confirmation, or live print.
class PrintDevCheckoutScreen extends ConsumerStatefulWidget {
  const PrintDevCheckoutScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.reviewedRevision,
  });
  final int albumId;
  final String albumTitle;
  final String reviewedRevision;
  @override
  ConsumerState<PrintDevCheckoutScreen> createState() =>
      _PrintDevCheckoutScreenState();
}

class _PrintDevCheckoutScreenState
    extends ConsumerState<PrintDevCheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _zip = TextEditingController();
  final _address = TextEditingController();
  final _detail = TextEditingController();
  final _memo = TextEditingController();
  PrintDevCheckoutSession? _session;
  Timer? _poll;
  bool _busy = false;
  bool _agreed = false;
  bool _started = false;
  String? _error;
  String? _progress;
  String? _notice;
  PrintDevCheckoutService get _service =>
      ref.read(printDevCheckoutServiceProvider);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_resume);
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in [_name, _phone, _zip, _address, _detail, _memo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _resume() async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final current = await _service.resume();
      final started = await _service.sdkStarted();
      if (!mounted) return;
      setState(() {
        _session = current;
        _started = started;
      });
      if (current != null) _schedule();
    } catch (e) {
      if (mounted)
        setState(
          () => _error = _withReferenceCode(
            '이전 개발 테스트를 확인하지 못했어요. 새 결제를 만들지 말고 다시 확인해주세요.',
            e,
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepare() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final current = await _service.prepare(
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
      if (!mounted) return;
      setState(() {
        _session = current;
        _agreed = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final current = _session;
    if (_busy ||
        !_agreed ||
        _started ||
        current == null ||
        current.albumId != widget.albumId ||
        current.reviewedRevision != widget.reviewedRevision)
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ready = await _service.prepareFiles(
        current,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      setState(() => _session = ready);
      final authorized = await _service.authorize(ready);
      if (!mounted) return;
      setState(() {
        _session = authorized;
        _started = true;
        _progress = '포트원 TEST 결제창 확인 중';
      });
      var sdk = authorized.sdkRequest!;
      if (kIsWeb && sdk.redirectUrl == null) {
        sdk = sdk.withReturnUrl(
          Uri.base.replace(path: '/', query: '', fragment: ''),
        );
      }
      await _service.assertCanLaunch(authorized);
      if (!mounted) return;
      await ref.read(portOnePaymentLauncherProvider)(context, sdk);
      if (!mounted) return;
      // The callback never confirms a receipt or submits a vendor order. Cron
      // observes the original TEST payment after this app has been closed.
      setState(
        () => _notice =
            '결제창 결과를 서버에서 확인하는 중입니다. 이제 앱을 닫아도 TEST 결제 확인과 업체 개발 주문이 이어집니다. 실제 책은 제작하지 않습니다.',
      );
      _schedule();
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
      try {
        final started = await _service.sdkStarted();
        if (mounted) setState(() => _started = started);
      } catch (_) {
        if (mounted) setState(() => _started = true);
      }
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = null;
        });
    }
  }

  void _schedule() {
    _poll?.cancel();
    if (mounted && _session != null) {
      _poll = Timer(const Duration(seconds: 20), _refresh);
    }
  }

  Future<void> _refresh() async {
    final current = _session;
    if (_busy || current == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final latest = await _service.status(current);
      if (mounted) setState(() => _session = latest);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = _withReferenceCode(
            '현재 개발 주문 상태를 읽지 못했어요. 기존 TEST 결제 ID를 보존하고 다시 확인해주세요.',
            e,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  String _friendly(Object error) {
    if (error is PrintDevCheckoutException) {
      final message = switch (error.code) {
        'admin_required' => '관리자 계정으로 로그인해야 개발 테스트를 진행할 수 있어요.',
        'existing_dev_test_pending' =>
          '진행 중인 개발 테스트가 있어요. 기존 결제·주문 결과부터 확인해주세요.',
        'test_payment_already_opened' =>
          '이미 연 TEST 결제창의 결과를 기다리는 중입니다. 같은 결제를 새로 실행하지 않습니다.',
        'print_dev_uploaded_files_need_recovery' =>
          '이미 만든 인쇄 파일을 보존했어요. 파일 검수 상태를 확인한 뒤 같은 테스트로 이어가주세요.',
        _ => '개발 테스트 준비를 완료하지 못했어요. 같은 테스트로 다시 확인해주세요. 결제 완료로 처리하지 않았습니다.',
      };
      return _withReferenceCode(message, error);
    }
    return _withReferenceCode(
      '인쇄 파일 또는 테스트 응답을 확인하지 못했어요. 결제 완료로 처리하지 않았습니다. 같은 테스트 상태를 다시 확인해주세요.',
      error,
    );
  }

  String _withReferenceCode(String message, Object error) {
    final code = switch (error) {
      PrintDevCheckoutException() => error.code,
      FormatException() => error.message,
      _ => '',
    };
    final reference = printDevErrorReference(code);
    return reference != null ? '$message\n참조 코드: $reference' : message;
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(printDevAdminAccessProvider);
    final current = _session;
    return PopScope(
      canPop: !_busy,
      child: _frame(
        body: !admin
            ? const Center(child: Text('관리자 권한이 필요합니다.'))
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'TEST · 실제 결제·제작 없음',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '앱에서 PDF 생성 → 포트원 TEST 결제 → 레드프린팅 개발 주문을 확인합니다. 실제 카드 청구·책 제작·배송은 진행하지 않습니다.',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.albumTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('300×300mm 하드커버 · 내지 80쪽 · 1권'),
                      const Text('TEST 결제 금액 159,900원'),
                      const SizedBox(height: 20),
                      if (current == null)
                        Form(
                          key: _form,
                          child: Column(
                            children: [
                              _field(_name, '받는 사람'),
                              _field(_phone, '연락처', number: true),
                              _field(_zip, '우편번호', number: true),
                              _field(_address, '주소'),
                              _field(_detail, '상세 주소', optional: true),
                              _field(_memo, '배송 요청 사항', optional: true),
                              const SizedBox(height: 12),
                              FilledButton(
                                key: const ValueKey('print-dev-prepare'),
                                onPressed: _busy ? null : _prepare,
                                child: const Text('이 앨범으로 개발 주문 준비'),
                              ),
                            ],
                          ),
                        ),
                      if (current != null) ...[
                        Text(
                          current.verifiedTest
                              ? '서버에 저장된 TEST 결제 영수증 확인 완료'
                              : _started
                              ? 'TEST 결제 확인 대기'
                              : 'TEST 결제 전',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          current.filesReady
                              ? '표지·내지 PDF 검수 완료'
                              : '표지·내지 PDF 준비 전',
                        ),
                        const SizedBox(height: 8),
                        Text(_stageLabel(current)),
                        if (current.devOrderNum != null)
                          Text('업체 개발 주문번호: ${current.devOrderNum}'),
                        const SizedBox(height: 12),
                        SelectableText(
                          '개발 주문 ID: ${current.orderId}\nTEST 결제 ID: ${current.paymentId}',
                        ),
                        if (!_started &&
                            !current.verifiedTest &&
                            current.albumId == widget.albumId &&
                            current.reviewedRevision ==
                                widget.reviewedRevision) ...[
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _agreed,
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _agreed = value == true),
                            title: const Text(
                              '80페이지 배치와 제작 규격을 확인했고, 실제 결제·제작이 없는 개발 테스트임을 확인했습니다.',
                            ),
                          ),
                          FilledButton(
                            key: const ValueKey('print-dev-test-pay'),
                            onPressed: _busy || !_agreed ? null : _pay,
                            child: const Text('PDF 생성·업로드 후 TEST 결제'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PDF 생성·업로드가 끝날 때까지 앱을 켜두세요. TEST 결제창 이후에는 앱을 닫아도 서버가 결과를 확인합니다.',
                          ),
                        ],
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('같은 개발 주문 상태 확인'),
                        ),
                      ],
                      if (_busy) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(_progress ?? '개발 테스트 상태 확인 중'),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: 16),
                        Text(_notice!),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!),
                        if (current == null)
                          TextButton(
                            onPressed: _busy ? null : _resume,
                            child: const Text('이전 테스트 다시 확인'),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _frame({required Widget body}) {
    if (!kIsWeb) return Scaffold(backgroundColor: SnapFitColors.backgroundOf(context), appBar: AppBar(title: const Text('개발 주문 테스트')), body: body);
    return SnapFitWebShell(
      title: '개발 주문',
      section: WebSection.orders,
      showNavigation: false,
      actions: [TextButton.icon(onPressed: _busy ? null : () => Navigator.maybePop(context), icon: const Icon(Icons.close, size: 18), label: const Text('돌아가기'))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WebPageHeading(eyebrow: 'ADMIN / DEVELOPMENT ONLY', title: '개발 주문 테스트', description: '관리자에게만 제공되는 TEST 주문 도구입니다. 실제 결제·제작·배송은 진행되지 않습니다.'),
        const SizedBox(height: 24),
        Expanded(child: LayoutBuilder(builder: (context, bounds) {
          if (bounds.maxWidth < 980) return WebSurface(padding: EdgeInsets.zero, child: body);
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: WebSurface(padding: EdgeInsets.zero, child: body)),
            const SizedBox(width: 24),
            SizedBox(width: 300, child: SingleChildScrollView(child: WebSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('테스트 범위', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 16),
              Text('인쇄 파일 준비\nTEST 결제 확인\n업체 개발 주문 상태', style: TextStyle(fontSize: 13, height: 2, color: WebPalette.of(context).muted)),
              SizedBox(height: 20),
              Divider(color: WebPalette.of(context).line),
              SizedBox(height: 16),
              Text('화면을 여는 것만으로 테스트가 시작되지는 않습니다.', style: TextStyle(fontSize: 12, height: 1.8, color: WebPalette.of(context).muted)),
            ])))),
          ]);
        })),
      ]),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool optional = false,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: ExperienceFormStyle.input(context).copyWith(labelText: label),
      validator: (value) => !optional && (value?.trim().isEmpty ?? true)
          ? '$label 정보를 입력해주세요.'
          : null,
    ),
  );
  String _stageLabel(PrintDevCheckoutSession session) =>
      switch (session.stage) {
        'DEV_SUBMITTED' || 'DEV_ACCEPTED' || 'ACCEPTED' => '업체 개발 주문 접수 확인',
        'DEV_FILE_CHECKED' || 'FILE_CHECKED' => '업체 개발 파일 확인 완료',
        'FAILED' || 'REVIEW_REQUIRED' => '개발 주문 확인 필요',
        _ =>
          session.verifiedTest
              ? '서버에서 업체 개발 주문 처리 중'
              : '서버가 기존 TEST 결제 결과를 확인합니다.',
      };
}
