import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../album/service/pending_album_invite.dart';
import '../../data/pending_referral.dart';
import '../views/referral_screen.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

/// Native links resume a code preview. Only the screen's explicit registration
/// action can grant points. Web links are presented by the browser router.
class ReferralLinkRouter extends ConsumerStatefulWidget {
  const ReferralLinkRouter({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<ReferralLinkRouter> createState() => _ReferralLinkRouterState();
}

class _ReferralLinkRouterState extends ConsumerState<ReferralLinkRouter> {
  static final _presented = Expando<ValueNotifier<PendingReferral>>();
  ProviderSubscription<PendingReferral?>? _subscription;
  ProviderSubscription<PendingAlbumInvite?>? _albumSubscription;
  PendingReferral? _seen;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _subscription = ref.listenManual(pendingReferralProvider, (_, next) {
      if (next != null) _schedule();
    }, fireImmediately: true);
    _albumSubscription = ref.listenManual(pendingAlbumInviteProvider, (
      _,
      next,
    ) {
      if (next == null) _schedule();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        unawaited(ref.read(pendingReferralProvider.notifier).restore());
    });
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || ref.read(pendingAlbumInviteProvider) != null) return;
      final invite = ref.read(pendingReferralProvider);
      if (invite == null || identical(invite, _seen)) return;
      _seen = invite;
      final navigator = Navigator.of(context, rootNavigator: true);
      final existing = _presented[navigator];
      if (existing != null) {
        existing.value = invite;
        return;
      }
      final active = ValueNotifier(invite);
      _presented[navigator] = active;
      navigator
          .push<void>(
            snapFitRoute<void>(page: ValueListenableBuilder<PendingReferral>(
                valueListenable: active,
                builder: (_, current, __) =>
                    ReferralScreen(initialCode: current.code),
              ), settings: WebAppRouteSettings(
                WebAppLocation(WebAppPage.referral, invite.code),
              )),
          )
          .whenComplete(() {
            if (identical(_presented[navigator], active))
              _presented[navigator] = null;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => active.dispose(),
            );
          });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _subscription?.close();
    _albumSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
