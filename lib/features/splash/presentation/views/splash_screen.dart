import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/screen_logger.dart';
import '../../../../core/navigation/app_root_route_observer.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/presentation/views/auth_gate.dart';
import '../../../../shared/web/web_design.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const Duration _minDisplayDuration = Duration(milliseconds: 900);
  static const Duration _fadeDuration = Duration(milliseconds: 350);
  late final DateTime _startedAt;
  late final ProviderSubscription<AsyncValue<UserInfo?>> _authSub;
  bool _isExiting = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter('SplashScreen', '앱 초기 로딩 · 인증 상태 확인 후 Login/Home 분기');
    _startedAt = DateTime.now();

    _authSub = ref.listenManual<AsyncValue<UserInfo?>>(authViewModelProvider, (
      previous,
      next,
    ) {
      if (next.isLoading) return;
      _startExit();
    });

    final current = ref.read(authViewModelProvider);
    if (!current.isLoading) {
      _startExit();
    }
  }

  @override
  void dispose() {
    _authSub.close();
    super.dispose();
  }

  Future<void> _startExit() async {
    if (_hasNavigated || _isExiting) return;
    _isExiting = true;
    final elapsed = DateTime.now().difference(_startedAt);
    final remaining = (kIsWeb ? Duration.zero : _minDisplayDuration) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: const AppRootRouteSettings(),
        transitionDuration: kIsWeb ? Duration.zero : _fadeDuration,
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: WebPalette.of(context).background,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_stories_outlined, size: 34, color: WebPalette.of(context).brand),
          SizedBox(height: 16),
          Text('스냅핏', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: WebPalette.of(context).ink)),
          SizedBox(height: 24),
          SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 2)),
        ])),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF101112),
      body: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, box) {
            final landscape = box.maxWidth > box.maxHeight;
            return Image.asset(
              landscape
                  ? 'assets/brand/album-mark/splash-landscape.png'
                  : 'assets/splash.png',
              fit: BoxFit.cover,
              alignment: landscape ? Alignment.center : Alignment.topCenter,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }
}
