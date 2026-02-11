import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:snap_fit/config/env.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart'; // tokenStorageProvider 위치에 따라 수정 필요
import 'dio_client.dart';
import 'auth_interceptor.dart'; // 1단계에서 만든 파일

part 'dio_provider.g.dart';

@riverpod
Dio dio(Ref ref) {
  // 1. TokenStorage 인스턴스 가져오기
  final tokenStorage = ref.read(tokenStorageProvider);

  // 2. Dio 인스턴스 생성
  final dio = DioClient.create(
    baseUrl: Env.baseUrl,
  );

  // 3. 인터셉터 추가
  dio.interceptors.add(AuthInterceptor(tokenStorage, dio));

  return dio;
}