import 'package:flutter/material.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/navigation/web_unsaved_work_guard.dart';
import '../../../../shared/widgets/experience_form_style.dart';

/// Protects a live inquiry without storing it or changing its submission state.
class InquiryExitGuard extends StatefulWidget {
  const InquiryExitGuard({
    super.key,
    required this.edits,
    required this.hasUnsavedChanges,
    required this.busy,
    required this.child,
  });

  final Listenable edits;
  final bool Function() hasUnsavedChanges;
  final bool busy;
  final Widget child;

  @override
  InquiryExitGuardState createState() => InquiryExitGuardState();
}

class InquiryExitGuardState extends State<InquiryExitGuard> {
  bool _handlingExit = false;
  bool _allowExit = false;
  bool _dialogDecisionMade = false;

  void _resolveDialog(BuildContext dialogContext, bool discard) {
    if (_dialogDecisionMade ||
        !dialogContext.mounted ||
        ModalRoute.of(dialogContext)?.isCurrent == false)
      return;
    _dialogDecisionMade = true;
    Navigator.pop(dialogContext, discard);
  }

  Future<void> requestClose() async {
    if (!mounted ||
        widget.busy ||
        _handlingExit ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    _handlingExit = true;
    final focusedInput = FocusManager.instance.primaryFocus;
    var restoreFocus = false;
    var closed = false;
    try {
      if (widget.hasUnsavedChanges()) {
        FocusManager.instance.primaryFocus?.unfocus();
        _dialogDecisionMade = false;
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Dialog(
            key: const ValueKey('inquiry-exit-dialog'),
            backgroundColor: SnapFitColors.backgroundOf(dialogContext),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '작성 중인 문의를 나갈까요?',
                      style: ExperienceFormStyle.text(
                        dialogContext,
                        20,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '나가면 작성한 내용이 사라져요. 계속 작성하려면 이 화면에 머물러 주세요.',
                      style: ExperienceFormStyle.text(
                        dialogContext,
                        14,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('inquiry-exit-continue'),
                      autofocus: true,
                      style: ExperienceFormStyle.primary(dialogContext),
                      onPressed: () => _resolveDialog(dialogContext, false),
                      child: const Text('계속 작성'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('inquiry-exit-discard'),
                      style: TextButton.styleFrom(
                        foregroundColor: ExperienceFormStyle.muted(
                          dialogContext,
                        ),
                        textStyle: ExperienceFormStyle.text(dialogContext, 14),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => _resolveDialog(dialogContext, true),
                      child: const Text('내용 버리고 나가기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (!mounted ||
            widget.busy ||
            ModalRoute.of(context)?.isCurrent == false)
          return;
        if (discard != true) {
          restoreFocus = true;
          return;
        }
        setState(() => _allowExit = true);
        // Let PopScope apply the user's explicit decision before maybePop.
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted || widget.busy || ModalRoute.of(context)?.isCurrent == false)
        return;
      closed = await Navigator.maybePop(context);
      if (!closed && mounted) {
        setState(() => _allowExit = false);
        restoreFocus = true;
      }
    } finally {
      _handlingExit = false;
      if (mounted && !closed && _allowExit) {
        setState(() => _allowExit = false);
      }
      if (mounted &&
          restoreFocus &&
          focusedInput?.context?.mounted == true &&
          ModalRoute.of(context)?.isCurrent != false) {
        focusedInput!.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) => WebUnsavedWorkGuard(
    hasUnsavedChanges: () =>
        !_allowExit && (widget.busy || widget.hasUnsavedChanges()),
    child: ListenableBuilder(
      listenable: widget.edits,
      builder: (context, _) => PopScope(
        canPop: !widget.busy && (_allowExit || !widget.hasUnsavedChanges()),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) requestClose();
        },
        child: widget.child,
      ),
    ),
  );
}
