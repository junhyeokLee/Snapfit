import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/snapfit_shimmer.dart';
import '../../../billing/data/billing_provider.dart';
import '../../domain/order_visibility_owner.dart';
import '../../../../shared/widgets/experience_icon.dart';

enum _PointAction { charge, history }

String _pointAmount(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')} P';

/// A quiet balance summary; account actions appear only when requested.
class MyPointBalanceCard extends ConsumerStatefulWidget {
  const MyPointBalanceCard({
    super.key,
    required this.onCharge,
    this.onHistory,
    this.compact = false,
    this.ownerId,
  });
  final VoidCallback onCharge;
  final VoidCallback? onHistory;
  final bool compact;
  final String? ownerId;

  @override
  ConsumerState<MyPointBalanceCard> createState() => _MyPointBalanceCardState();
}

class _MyPointBalanceCardState extends ConsumerState<MyPointBalanceCard> {
  int _revision = 0;
  ModalBottomSheetRoute<_PointAction>? _sheet;
  NavigatorState? _sheetNavigator;

  bool _current(int revision, String? owner) =>
      mounted &&
      revision == _revision &&
      (widget.ownerId == null || widget.ownerId == owner) &&
      ref.read(visibleOrderOwnerProvider) == owner;

  void _dismissSheet() {
    final route = _sheet, navigator = _sheetNavigator;
    _sheet = null;
    _sheetNavigator = null;
    if (route == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  @override
  void didUpdateWidget(covariant MyPointBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      _revision++;
      _dismissSheet();
    }
  }

  @override
  void dispose() {
    _revision++;
    _dismissSheet();
    super.dispose();
  }

  Future<void> _openDetails() async {
    if (_sheet != null) return;
    final owner = widget.ownerId ?? ref.read(visibleOrderOwnerProvider);
    final revision = _revision;
    if (!_current(revision, owner)) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final providers = ProviderScope.containerOf(context);
    late final ModalBottomSheetRoute<_PointAction> route;
    route = ModalBottomSheetRoute<_PointAction>(
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      modalBarrierColor: Colors.black45,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UncontrolledProviderScope(
        container: providers,
        child: _PointDetails(
          owner: owner,
          isCurrent: () => _current(revision, owner),
          onClose: _dismissSheet,
          history: widget.onHistory != null,
          onAction: (action) {
            if (_current(revision, owner) && route.isCurrent)
              navigator.pop(action);
          },
        ),
      ),
    );
    _sheet = route;
    _sheetNavigator = navigator;
    _PointAction? action;
    try {
      action = await navigator.push(route);
    } finally {
      if (identical(_sheet, route)) {
        _sheet = null;
        _sheetNavigator = null;
      }
    }
    if (!_current(revision, owner)) return;
    switch (action) {
      case _PointAction.charge:
        widget.onCharge();
      case _PointAction.history:
        widget.onHistory?.call();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(visibleOrderOwnerProvider);
    ref.listen<String?>(visibleOrderOwnerProvider, (previous, next) {
      if (previous == next) return;
      _revision++;
      _dismissSheet();
    });
    if (widget.ownerId != null && widget.ownerId != owner)
      return const SizedBox.shrink();
    final balance = ref.watch(myPointBalanceProvider);
    final amount = balance.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      data: (value) => Text(
        _pointAmount(value),
        style: ExperienceFormStyle.text(
          context,
          widget.compact ? 15 : 16,
          weight: FontWeight.w600,
        ),
      ),
      loading: () =>
          const SnapFitShimmer(child: SnapFitShimmerBox(width: 72, height: 16)),
      error: (_, _) => Text(
        '잔액 확인 필요',
        style: ExperienceFormStyle.text(context, 13, secondary: true),
      ),
    );
    return Material(
      key: const ValueKey('my-point-balance-card'),
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        label: '포인트 메뉴 열기',
        onTap: _openDetails,
        child: InkWell(
          key: const ValueKey('my-point-summary'),
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(10),
          onTap: _openDetails,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  ExperienceIcon('Coins', size: 18, color: ExperienceFormStyle.selectionInk(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '포인트',
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            secondary: true,
                          ),
                        ),
                        amount,
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExperienceIcon('ChevronDown', size: 19, color: ExperienceFormStyle.muted(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PointDetails extends ConsumerStatefulWidget {
  const _PointDetails({
    required this.owner,
    required this.isCurrent,
    required this.onClose,
    required this.history,
    required this.onAction,
  });
  final String? owner;
  final bool Function() isCurrent;
  final VoidCallback onClose;
  final bool history;
  final ValueChanged<_PointAction> onAction;

  @override
  ConsumerState<_PointDetails> createState() => _PointDetailsState();
}

class _PointDetailsState extends ConsumerState<_PointDetails> {
  bool _closing = false;

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(visibleOrderOwnerProvider);
    if (owner != widget.owner || !widget.isCurrent()) {
      if (!_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onClose();
        });
      }
      return const SizedBox.shrink();
    }
    final balance = ref.watch(myPointBalanceProvider);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('my-point-details'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '내 포인트',
                    style: ExperienceFormStyle.text(
                      context,
                      18,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('my-point-close'),
                  tooltip: '포인트 닫기',
                  onPressed: widget.onClose,
                  icon: const ExperienceIcon('X'),
                ),
              ],
            ),
            balance.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              data: (value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _pointAmount(value),
                  style: ExperienceFormStyle.text(
                    context,
                    28,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SnapFitShimmer(
                  child: SnapFitShimmerBox(width: 120, height: 28),
                ),
              ),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '잔액을 확인하지 못했어요.',
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      secondary: true,
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('my-point-retry'),
                    onPressed: () {
                      if (widget.isCurrent())
                        ref.invalidate(myPointBalanceProvider);
                    },
                    icon: const ExperienceIcon('RefreshCw', size: 18),
                    label: const Text('다시 확인'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const ValueKey('my-point-charge'),
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 12,
              leading: ExperienceIcon('Plus', color: ExperienceFormStyle.selectionInk(context),
              ),
              title: const Text('포인트 충전'),
              trailing: const ExperienceIcon('ChevronRight'),
              onTap: () => widget.onAction(_PointAction.charge),
            ),
            if (widget.history)
              ListTile(
                key: const ValueKey('my-point-history'),
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 12,
                leading: const ExperienceIcon('FileText'),
                title: const Text('이용내역'),
                trailing: const ExperienceIcon('ChevronRight'),
                onTap: () => widget.onAction(_PointAction.history),
              ),
          ],
        ),
      ),
    );
  }
}
