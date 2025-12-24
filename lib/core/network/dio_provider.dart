import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/album/data/api/album_api.dart';
import 'dio_client.dart';

part 'dio_provider.g.dart';

const String _baseUrl = 'http://localhost:8080';

@riverpod
Dio dio(Ref ref) {
  return DioClient.create(
    baseUrl: _baseUrl,
  );
}
