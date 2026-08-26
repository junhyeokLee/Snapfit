import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/screen_logger.dart';
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
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101112),
      body: SizedBox.expand(
        child: AnimatedOpacity(
          duration: _fadeDuration,
          opacity: _isExiting ? 0 : 1,
          curve: Curves.easeOut,
          child: AnimatedScale(
            duration: _fadeDuration,
            scale: _isExiting ? 1.02 : 1.0,
            curve: Curves.easeOut,
            child: const _SplashAlbumObject(),
          ),
        ),
      ),
    );
  }
}

class _SplashAlbumObject extends StatefulWidget {
  const _SplashAlbumObject();

  @override
  State<_SplashAlbumObject> createState() => _SplashAlbumObjectState();
}

class _SplashAlbumObjectState extends State<_SplashAlbumObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _float = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        const _SplashGrain(),
        Center(
          child: AnimatedBuilder(
            animation: _float,
            builder: (context, child) {
              final t = _float.value;
              return Transform.translate(
                offset: Offset(0, -10 - (12 * t)),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateY((-9 + (6 * t)) * 0.0174533)
                    ..rotateZ((-2 + (2.5 * t)) * 0.0174533),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 244,
              height: 326,
              decoration: BoxDecoration(
                color: const Color(0xFF171819),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.48),
                    blurRadius: 58,
                    offset: const Offset(0, 34),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/snapfit_splash_album_cover.jpg',
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 42,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.44),
                            Colors.white.withOpacity(0.16),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.24)),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 104,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SnapFit',
                style: TextStyle(
                  color: textColor,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'album object loading',
                style: TextStyle(
                  color: textColor.withOpacity(0.56),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplashGrain extends StatelessWidget {
  const _SplashGrain();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _SplashGrainPainter());
  }
}

class _SplashGrainPainter extends CustomPainter {
  const _SplashGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFF101112), Color(0xFF171615)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final dot = Paint()..color = Colors.white.withOpacity(0.035);
    for (double x = 0; x < size.width; x += 4) {
      for (double y = 0; y < size.height; y += 4) {
        if (((x + y) ~/ 4) % 3 == 0) {
          canvas.drawCircle(Offset(x, y), 0.55, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplashGrainPainter oldDelegate) => false;
}
