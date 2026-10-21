import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/web/web_design.dart';
import '../../../album/presentation/views/home_screen.dart';
import '../../../album/presentation/widgets/album_invite_router.dart';
import '../viewmodels/auth_view_model.dart';
import '../../domain/web_oauth.dart';
import 'login_screen.dart';
import '../../../store/presentation/views/public_discovery_screen.dart';
import '../../../store/presentation/views/template_detail_screen.dart';
import '../../data/dto/auth_response.dart';
import '../providers/public_template_return_intent.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, this.allowDiscovery = true});
  final bool allowDiscovery;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _accountOwner;
  int _authRevision = 0;
  Route<void>? _returnedTemplateRoute;
  NavigatorState? _returnedTemplateNavigator;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      ref.listenManual(
        authViewModelProvider,
        _authChanged,
        fireImmediately: true,
      );
    }
  }

  void _authChanged(
    AsyncValue<UserInfo?>? previous,
    AsyncValue<UserInfo?> next,
  ) {
    final revision = ++_authRevision;
    // Loading and recoverable errors invalidate a scheduled callback without
    // treating a temporary auth refresh as a logout.
    if (next.isLoading || next.hasError) return;
    final owner = next.asData?.value?.id;
    final changedAccount = _accountOwner != null && _accountOwner != owner;
    _accountOwner = owner;
    if (changedAccount) {
      ref.read(publicTemplateReturnIntentProvider.notifier).clear();
      _removeReturnedTemplate();
      return;
    }
    if (owner == null || ref.read(publicTemplateReturnIntentProvider) == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _authRevision ||
          ref.read(authViewModelProvider).asData?.value?.id != owner ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final template = ref
          .read(publicTemplateReturnIntentProvider.notifier)
          .consume();
      if (template == null) return;
      final navigator = Navigator.of(context);
      final route = MaterialPageRoute<void>(
        builder: (_) => TemplateDetailScreen(template: template),
      );
      _returnedTemplateRoute = route;
      _returnedTemplateNavigator = navigator;
      navigator.push(route).whenComplete(() {
        if (identical(_returnedTemplateRoute, route)) {
          _returnedTemplateRoute = null;
          _returnedTemplateNavigator = null;
        }
      });
    });
  }

  void _removeReturnedTemplate() {
    final route = _returnedTemplateRoute;
    final navigator = _returnedTemplateNavigator;
    _returnedTemplateRoute = null;
    _returnedTemplateNavigator = null;
    if (route == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewModelProvider);
    return AlbumInviteRouter(
      child: authAsync.when(
        data: (user) => user == null
            ? kIsWeb && widget.allowDiscovery
                  ? const PublicDiscoveryScreen()
                  : const LoginScreen()
            : const HomeScreen(),
        loading: () => kIsWeb
            ? SnapFitWebShell(
                showNavigation: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        '로그인한 계정을 확인하고 있어요.',
                        style: TextStyle(color: WebPalette.of(context).muted),
                      ),
                    ],
                  ),
                ),
              )
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) =>
            LoginScreen(authNotice: socialAuthErrorMessage(error)),
      ),
    );
  }
}
