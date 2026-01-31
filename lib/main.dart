import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'features/album/presentation/views/add_cover_screen.dart';
import 'features/album/presentation/views/home_screen.dart';
import 'firebase_options.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true, // 글자 크기 자동 조정
        splitScreenMode: true, // 분할 화면 대응 (Fold, Split 등)
        builder: (context, child) {
          return const MoaEditorApp();
        },
      ),
    ),
  );
}

class MoaEditorApp extends StatelessWidget {
  const MoaEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
      routes: {
        '/add_cover': (context) => const AddCoverScreen(),
      },
    );
  }
}