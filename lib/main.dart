import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';

import 'config/env.dart';
import 'core/theme/snapfit_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/album/presentation/views/add_cover_screen.dart';
import 'features/auth/presentation/views/auth_gate.dart';
import 'features/splash/presentation/views/splash_screen.dart';
import 'firebase_options.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Env.kakaoNativeAppKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  }

  runApp(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true, // 글자 크기 자동 조정
        splitScreenMode: true, // 분할 화면 대응 (Fold,ㄹ Split 등)
        builder: (context, child) {
          return const MoaEditorApp();
        },
      ),
    ),
  );
}

class MoaEditorApp extends ConsumerStatefulWidget {
  const MoaEditorApp({super.key});

  @override
  ConsumerState<MoaEditorApp> createState() => _MoaEditorAppState();
}

class _MoaEditorAppState extends ConsumerState<MoaEditorApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeModeControllerProvider.notifier).loadFromStorage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp(
      title: 'SnapFit',
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light(),
      darkTheme: SnapFitTheme.dark(),
      themeMode: themeMode,
      home: const SplashScreen(),
      routes: {
        '/add_cover': (context) => const AddCoverScreen(),
      },
    );
  }
}