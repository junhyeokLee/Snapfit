import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/presentation/views/auth_gate.dart';

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
    _startedAt = DateTime.now();

    _authSub = ref.listenManual<AsyncValue<UserInfo?>>(authViewModelProvider,
        (previous, next) {
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
    final elapsed = DateTime.now().difference(_startedAt);
    final remaining = _minDisplayDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    setState(() => _isExiting = true);
    await Future.delayed(_fadeDuration);
    if (!mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: SizedBox.expand(
        child: AnimatedOpacity(
          duration: _fadeDuration,
          opacity: _isExiting ? 0 : 1,
          curve: Curves.easeOut,
          child: AnimatedScale(
            duration: _fadeDuration,
            scale: _isExiting ? 1.02 : 1.0,
            curve: Curves.easeOut,
            child: const Image(
              image: AssetImage('assets/splash.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
