import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/pending_album_invite.dart';
import '../views/album_invite_accept_screen.dart';

/// Mounted by AuthGate after splash; leaves existing editor routes intact.
class AlbumInviteRouter extends ConsumerStatefulWidget {
  const AlbumInviteRouter({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AlbumInviteRouter> createState() => _AlbumInviteRouterState();
}

class _AlbumInviteRouterState extends ConsumerState<AlbumInviteRouter> {
  late final ProviderSubscription<PendingAlbumInvite?> _subscription;
  ValueNotifier<PendingAlbumInvite>? _active;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(pendingAlbumInviteProvider, (_, invite) {
      if (invite == null) return;
      if (_active != null) {
        _active!.value = invite;
      } else {
        _scheduleOpen();
      }
    }, fireImmediately: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        unawaited(ref.read(pendingAlbumInviteProvider.notifier).restore());
    });
  }

  void _scheduleOpen() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _active != null) return;
      final invite = ref.read(pendingAlbumInviteProvider);
      if (invite != null) unawaited(_open(invite));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _open(PendingAlbumInvite invite) async {
    final active = ValueNotifier(invite);
    _active = active;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/album-invitation'),
        builder: (_) => ValueListenableBuilder<PendingAlbumInvite>(
          valueListenable: active,
          builder: (_, current, __) =>
              AlbumInviteAcceptScreen(key: ObjectKey(current), invite: current),
        ),
      ),
    );
    _active = null;
    if (mounted && ref.read(pendingAlbumInviteProvider) != null)
      _scheduleOpen();
    // Route widgets can remain mounted until the reverse transition finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) => active.dispose());
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
