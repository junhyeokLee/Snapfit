import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../data/support_inquiry_repository.dart';
import '../../domain/order_visibility_owner.dart';
import 'customer_web_page.dart';

/// 한 번 계정이 바뀐 문의 화면은 이전 계정으로 돌아와도 다시 노출하지 않는다.
class SupportInquiryOwnerGuard extends ConsumerStatefulWidget {
  const SupportInquiryOwnerGuard({
    super.key,
    required this.ownerId,
    required this.child,
    this.onInvalidated,
  });

  final String ownerId;
  final Widget child;
  final VoidCallback? onInvalidated;

  @override
  ConsumerState<SupportInquiryOwnerGuard> createState() =>
      _SupportInquiryOwnerGuardState();
}

class _SupportInquiryOwnerGuardState
    extends ConsumerState<SupportInquiryOwnerGuard> {
  StreamSubscription<String?>? _session;
  bool _invalidated = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(supportInquiryRepositoryProvider).authChanges.listen((
      owner,
    ) {
      if (owner != widget.ownerId) _invalidate();
    }, onError: (Object _, StackTrace _) => _invalidate());
  }

  void _invalidate() {
    if (!mounted || _invalidated) return;
    _invalidated = true;
    widget.onInvalidated?.call();
    setState(() {});
  }

  @override
  void dispose() {
    unawaited(_session?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(visibleOrderOwnerProvider);
    final repository = ref.watch(supportInquiryRepositoryProvider);
    ref.listen(visibleOrderOwnerProvider, (_, next) {
      if (next != widget.ownerId) _invalidate();
    });
    ref.listen(supportInquiryRepositoryProvider, (previous, next) {
      if (!identical(previous, next)) _invalidate();
    });
    if (!_invalidated &&
        (owner != widget.ownerId ||
            repository.currentUserId != widget.ownerId)) {
      _invalidated = true;
      // 부모의 세대·캐시만 무효화하며 여기서 부모의 setState는 호출하지 않는다.
      widget.onInvalidated?.call();
    }
    if (!_invalidated) return widget.child;
    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: const Text(
                '로그인 계정이 변경되었어요.\n고객센터를 다시 열어주세요.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
    if (kIsWeb) return CustomerWebPage(title: '고객센터', child: content);
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: const ExperienceHeader(title: '고객센터', showNotifications: false),
      body: SafeArea(child: content),
    );
  }
}
