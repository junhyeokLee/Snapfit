import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../data/support_inquiry_repository.dart';
import '../../domain/order_visibility_owner.dart';
import '../widgets/customer_web_page.dart';
import '../widgets/inquiry_exit_guard.dart';

class SupportInquiryScreen extends ConsumerStatefulWidget {
  const SupportInquiryScreen({
    super.key,
    this.initialCategory = 'GENERAL',
    this.initialSubject = '',
  });
  final String initialCategory, initialSubject;

  @override
  ConsumerState<SupportInquiryScreen> createState() =>
      _SupportInquiryScreenState();
}

class _SupportInquiryScreenState extends ConsumerState<SupportInquiryScreen> {
  static const List<String> _categories = <String>[
    'GENERAL',
    'ORDER',
    'PAYMENT',
    'DELIVERY',
    'BUG',
  ];

  late final _initialCategory = _categories.contains(widget.initialCategory)
      ? widget.initialCategory
      : _categories.first;
  late String _category = _initialCategory;
  late final _initialSubject = widget.initialSubject;
  late final _subjectController = TextEditingController(text: _initialSubject);
  final _messageController = TextEditingController();
  late final _draftEdits = Listenable.merge([
    _subjectController,
    _messageController,
  ]);
  final _exitGuardKey = GlobalKey<InquiryExitGuardState>();
  final _subjectFocus = FocusNode();
  final _messageFocus = FocusNode();
  bool _submitting = false;
  bool _sent = false;
  String? _submissionError;
  final _formKey = GlobalKey<FormState>();
  final _detailsKey = GlobalKey(), _messageKey = GlobalKey();
  final _detailsScroll = ScrollController(),
      _messageScroll = ScrollController();
  final _portraitScroll = ScrollController();
  bool _focusQueued = false;
  Size? _lastSize;
  double? _lastInset;
  String? _webOwnerId;
  bool get _webOwnerCurrent =>
      _webOwnerId != null && ref.read(visibleOrderOwnerProvider) == _webOwnerId;
  bool get _hasDraftChanges =>
      !_sent &&
      (!kIsWeb || _webOwnerCurrent) &&
      (_category != _initialCategory ||
          _subjectController.text != _initialSubject ||
          _messageController.text.isNotEmpty);

  void _ensureFocusedInput() {
    if (_focusQueued) return;
    _focusQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusQueued = false;
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final focus = _messageFocus.hasFocus ? _messageFocus : _subjectFocus;
      final input = focus.context;
      if (focus.hasFocus && input != null && input.mounted) {
        Scrollable.ensureVisible(input, alignment: .25);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    if (_lastSize == media.size && _lastInset == media.viewInsets.bottom)
      return;
    _lastSize = media.size;
    _lastInset = media.viewInsets.bottom;
    _ensureFocusedInput();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _subjectFocus.dispose();
    _messageFocus.dispose();
    _detailsScroll.dispose();
    _messageScroll.dispose();
    _portraitScroll.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted || _submitting || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _exitGuardKey.currentState?.requestClose();
  }

  Future<void> _submit() async {
    if (!mounted ||
        _submitting ||
        _sent ||
        (kIsWeb && !_webOwnerCurrent) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      (_subjectController.text.trim().isEmpty ? _subjectFocus : _messageFocus)
          .requestFocus();
      _ensureFocusedInput();
      return;
    }
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')));
      return;
    }
    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    try {
      await ref
          .read(supportInquiryRepositoryProvider)
          .createInquiry(
            category: _category,
            subject: subject,
            message: message,
          );
      if (!mounted) return;
      setState(() => _sent = true);
      if (kIsWeb && !_webOwnerCurrent) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문의가 접수되었습니다. 빠르게 답변드릴게요.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted || (kIsWeb && !_webOwnerCurrent)) return;
      final msg = AppErrorMapper.toUserMessage(e);
      setState(() => _submissionError = '문의 접수 실패: $msg');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    const labels = {
      'GENERAL': '계정 · 기타',
      'ORDER': '주문',
      'PAYMENT': '템플릿 · 소재 구매',
      'DELIVERY': '인쇄 · 배송',
      'BUG': '앨범 편집 · 오류',
    };
    if (kIsWeb) {
      final owner = ref.watch(visibleOrderOwnerProvider);
      if (owner != null && _webOwnerId == null) _webOwnerId = owner;
      if (owner == null || owner != _webOwnerId) {
        return CustomerWebPage(
          title: '고객센터',
          eyebrow: 'SUPPORT',
          showNavigation: false,
          allowBack: !_submitting,
          child: const Center(
            child: Text('로그인 계정이 변경되었어요. 이 화면을 닫고 문의를 다시 작성해주세요.'),
          ),
        );
      }
      return _webInquiry(labels);
    }
    Widget label(String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        value,
        style: ExperienceFormStyle.text(context, 13, weight: FontWeight.w600),
      ),
    );
    return InquiryExitGuard(
      key: _exitGuardKey,
      edits: _draftEdits,
      hasUnsavedChanges: () => _hasDraftChanges,
      busy: _submitting,
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: ExperienceHeader(title: '문의', themeAware: true, onBack: _close),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, bounds) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      bounds.maxWidth >= 540 &&
                          MediaQuery.orientationOf(context) ==
                              Orientation.landscape
                      ? 1000
                      : 600,
                ),
                child: AbsorbPointer(
                  absorbing: _submitting,
                  child: Form(
                    key: _formKey,
                    child: LayoutBuilder(
                      builder: (context, formBounds) {
                        final wide =
                            formBounds.maxWidth >= 540 &&
                            MediaQuery.orientationOf(context) ==
                                Orientation.landscape;
                        final compactInput =
                            wide &&
                            (keyboardVisible || formBounds.maxHeight < 180);
                        final details = KeyedSubtree(
                          key: _detailsKey,
                          child: Semantics(
                            container: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!wide) ...[
                                  Text(
                                    '무엇을 도와드릴까요?',
                                    style: ExperienceFormStyle.text(
                                      context,
                                      22,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '구매한 디자인이나 앨범에 대해 편하게 남겨 주세요.',
                                    style: ExperienceFormStyle.text(
                                      context,
                                      14,
                                      secondary: true,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                label('문의 유형'),
                                DropdownButtonFormField<String>(
                                  key: const ValueKey('support-category'),
                                  itemHeight: null,
                                  initialValue: _category,
                                  isExpanded: true,
                                  decoration: ExperienceFormStyle.input(
                                    context,
                                    hint: '문의 유형',
                                  ),
                                  dropdownColor: SnapFitColors.surfaceOf(
                                    context,
                                  ),
                                  style: ExperienceFormStyle.text(context, 14),
                                  items: _categories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(labels[c]!),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _sent
                                      ? null
                                      : (value) {
                                          if (mounted &&
                                              !_submitting &&
                                              !_sent &&
                                              ModalRoute.of(
                                                    context,
                                                  )?.isCurrent !=
                                                  false &&
                                              value != null)
                                            setState(() => _category = value);
                                        },
                                ),
                                SizedBox(height: wide ? 12 : 20),
                                label('제목'),
                                TextFormField(
                                  key: const ValueKey('support-subject'),
                                  enabled: !_sent,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  controller: _subjectController,
                                  focusNode: _subjectFocus,
                                  maxLength: 80,
                                  style: ExperienceFormStyle.text(context, 14),
                                  decoration: ExperienceFormStyle.input(
                                    context,
                                    hint: '문의 제목을 입력해 주세요',
                                  ).copyWith(errorMaxLines: 3),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) =>
                                      value?.trim().isNotEmpty == true
                                      ? null
                                      : '제목을 입력해주세요.',
                                ),
                              ],
                            ),
                          ),
                        );
                        final message = KeyedSubtree(
                          key: _messageKey,
                          child: Semantics(
                            container: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                label('문의 내용'),
                                TextFormField(
                                  key: const ValueKey('support-message'),
                                  enabled: !_sent,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  controller: _messageController,
                                  focusNode: _messageFocus,
                                  minLines: compactInput
                                      ? 1
                                      : wide
                                      ? 2
                                      : 5,
                                  maxLines: compactInput
                                      ? 2
                                      : wide
                                      ? 7
                                      : 10,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  maxLength: 1000,
                                  style: ExperienceFormStyle.text(context, 14),
                                  decoration:
                                      ExperienceFormStyle.input(
                                        context,
                                        hint: '불편한 점을 알려 주세요.',
                                      ).copyWith(
                                        errorMaxLines: 3,
                                        counterText: compactInput ? '' : null,
                                        contentPadding: compactInput
                                            ? const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              )
                                            : null,
                                      ),
                                  validator: (value) =>
                                      value?.trim().isNotEmpty == true
                                      ? null
                                      : '문의 내용을 입력해주세요.',
                                ),
                              ],
                            ),
                          ),
                        );
                        final action = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_sent) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  '문의가 접수되었습니다.',
                                  style: ExperienceFormStyle.text(context, 14),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_submissionError != null) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _submissionError!,
                                  key: const ValueKey('support-error'),
                                  style: ExperienceFormStyle.text(
                                    context,
                                    13,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            FilledButton(
                              key: const ValueKey('support-submit'),
                              onPressed: _submitting
                                  ? null
                                  : _sent
                                  ? _close
                                  : _submit,
                              style: ExperienceFormStyle.primary(context),
                              child: _submitting
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Flexible(child: Text('접수 중')),
                                      ],
                                    )
                                  : Text(_sent ? '완료' : '문의 보내기'),
                            ),
                          ],
                        );
                        if (wide) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                            child: Row(
                              key: const ValueKey('support-wide-form'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _detailsScroll,
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: details,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, body) {
                                      final inlineAction =
                                          body.maxHeight < 160 ||
                                          _submissionError != null;
                                      final content = SingleChildScrollView(
                                        controller: _messageScroll,
                                        keyboardDismissBehavior:
                                            ScrollViewKeyboardDismissBehavior
                                                .onDrag,
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            message,
                                            if (inlineAction) ...[
                                              const SizedBox(height: 12),
                                              action,
                                            ],
                                          ],
                                        ),
                                      );
                                      return inlineAction
                                          ? content
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(child: content),
                                                const SizedBox(height: 12),
                                                action,
                                              ],
                                            );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return SingleChildScrollView(
                          controller: _portraitScroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            24,
                            wide ? 12 : 24,
                            24,
                            wide ? 16 : 28,
                          ),
                          child: Column(
                            children: [
                              details,
                              const SizedBox(height: 12),
                              message,
                              const SizedBox(height: 20),
                              action,
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _webInquiry(Map<String, String> labels) => InquiryExitGuard(
    key: _exitGuardKey,
    edits: _draftEdits,
    hasUnsavedChanges: () => _hasDraftChanges,
    busy: _submitting,
    child: CustomerWebPage(
      title: '고객센터',
      description: '궁금한 내용이나 이용 중 불편했던 점을 남겨주세요.',
      showNavigation: false,
      allowBack: !_submitting,
      onBack: _close,
      scrollBody: true,
      sidebar: const CustomerWebNote(
        title: '문의 작성 안내',
        message:
            '앨범 이름, 주문번호와 문제가 발생한 상황을 함께 적어주시면 내용을 확인하는 데 도움이 됩니다.\n\n취소·환불은 주문내역에서 해당 주문의 문의 기능을 이용해주세요.',
      ),
      child: AbsorbPointer(
        absorbing: _submitting,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('문의 작성', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                key: const ValueKey('support-category'),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '문의 유형'),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(labels[category]!),
                      ),
                    )
                    .toList(),
                onChanged: _sent
                    ? null
                    : (category) {
                        if (mounted && !_submitting && category != null) {
                          setState(() => _category = category);
                        }
                      },
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('support-subject'),
                controller: _subjectController,
                focusNode: _subjectFocus,
                enabled: !_sent,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '문의 제목을 입력해주세요.',
                ),
                validator: (value) =>
                    value?.trim().isNotEmpty == true ? null : '제목을 입력해주세요.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('support-message'),
                controller: _messageController,
                focusNode: _messageFocus,
                enabled: !_sent,
                minLines: 6,
                maxLines: 16,
                maxLength: 1000,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: '문의 내용',
                  hintText: '확인이 필요한 내용을 자세히 적어주세요.',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    value?.trim().isNotEmpty == true ? null : '문의 내용을 입력해주세요.',
              ),
              if (_submissionError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _submissionError!,
                    key: const ValueKey('support-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const ValueKey('support-submit'),
                  onPressed: _submitting
                      ? null
                      : _sent
                      ? _close
                      : _submit,
                  icon: Icon(
                    _sent ? Icons.check : Icons.send_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _submitting
                        ? '접수 중'
                        : _sent
                        ? '확인하고 닫기'
                        : '문의 접수하기',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
