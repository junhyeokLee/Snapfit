import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/web/web_design.dart';
import '../../../album/presentation/views/home_screen.dart';
import '../../../album/presentation/widgets/album_invite_router.dart';
import '../viewmodels/auth_view_model.dart';
import '../../domain/web_oauth.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authViewModelProvider);
    return AlbumInviteRouter(
      child: authAsync.when(
        data: (user) => user == null ? const LoginScreen() : const HomeScreen(),
        loading: () => kIsWeb
            ? SnapFitWebShell(
                showNavigation: false,
                child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('로그인한 계정을 확인하고 있어요.',
                      style: TextStyle(color: WebPalette.of(context).muted)),
                  ],
                )),
              )
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) =>
            LoginScreen(authNotice: socialAuthErrorMessage(error)),
      ),
    );
  }
}
