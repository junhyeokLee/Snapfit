import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../data/social_repository.dart' show socialActionMessage;
import '../providers/social_providers.dart';
import 'social_widgets.dart';
import '../../../../shared/widgets/experience_icon.dart';

const socialReportReasonLabels = <String, String>{
  'spam': '스팸·광고',
  'harassment': '괴롭힘·혐오 표현',
  'privacy': '개인정보 노출',
  'inappropriate': '부적절한 사진·내용',
  'copyright': '저작권 침해',
  'other': '기타',
};

typedef SocialReportSubmit =
    Future<void> Function(String reason, String detail, String requestId);

Future<bool> showSocialReportSheet(
  BuildContext context, {
  required String title,
  required String ownerId,
  required SocialReportSubmit onSubmit,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) =>
          SocialReportSheet(title: title, ownerId: ownerId, onSubmit: onSubmit),
    ) ??
    false;

class SocialReportSheet extends ConsumerStatefulWidget {
  const SocialReportSheet({
    super.key,
    required this.title,
    required this.ownerId,
    required this.onSubmit,
  });

  final String title, ownerId;
  final SocialReportSubmit onSubmit;

  @override
  ConsumerState<SocialReportSheet> createState() => _SocialReportSheetState();
}

class _SocialReportSheetState extends ConsumerState<SocialReportSheet> {
  final _detail = TextEditingController();
  String? _reason, _error;
  String _requestId = const Uuid().v4();
  bool _busy = false, _sessionChanged = false;

  bool get _current =>
      mounted &&
      !_sessionChanged &&
      ref.read(socialCurrentUserIdProvider) == widget.ownerId;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  void _close([bool sent = false]) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      route.navigator?.pop(sent);
    } else {
      route.navigator?.removeRoute(route);
    }
  }

  Future<void> _submit() async {
    if (!_current || _busy || _reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_reason!, _detail.text.trim(), _requestId);
      if (_current) _close(true);
    } catch (error) {
      if (_current) {
        setState(
          () => _error = socialActionMessage(
            error,
            fallback: '신고 접수를 확인하지 못했어요. 같은 내용으로 다시 시도해 주세요.',
          ),
        );
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(socialCurrentUserIdProvider);
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _sessionChanged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    });
    if (!_current) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .84,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: ExperienceFormStyle.text(
                        context,
                        22,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('social-report-close'),
                    tooltip: '닫기',
                    onPressed: _close,
                    icon: const ExperienceIcon('X'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '신고 사유를 골라 주세요. 접수한 내용은 운영자가 확인해요.',
                style: ExperienceFormStyle.text(context, 13, secondary: true),
              ),
              const SizedBox(height: 12),
              for (final reason in socialReportReasonLabels.entries)
                Semantics(
                  selected: _reason == reason.key,
                  child: ListTile(
                    key: ValueKey('social-report-reason-${reason.key}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason.value),
                    trailing: Icon(
                      _reason == reason.key
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _reason == reason.key
                          ? SocialStyle.accent(context)
                          : null,
                    ),
                    onTap: _busy
                        ? null
                        : () => setState(() {
                            _reason = reason.key;
                            _requestId = const Uuid().v4();
                            _error = null;
                          }),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('social-report-detail'),
                controller: _detail,
                enabled: !_busy,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: ExperienceFormStyle.input(
                  context,
                  hint: '추가로 알려주실 내용 (선택)',
                ),
                onChanged: (_) {
                  _requestId = const Uuid().v4();
                  if (_error != null) setState(() => _error = null);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: ExperienceFormStyle.text(context, 13),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('social-report-submit'),
                style: SocialStyle.primary(context),
                onPressed: _busy || _reason == null ? null : _submit,
                child: Text(_busy ? '접수하고 있어요…' : '신고 접수'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
