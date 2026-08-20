import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interceptors/token_storage.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';

class SupportInquiryRepository {
  SupportInquiryRepository({required this.dio, required this.tokenStorage, this.supabase});

  final Dio dio;
  final TokenStorage tokenStorage;
  final SupabaseClient? supabase;

  Future<void> createInquiry({
    required String category,
    required String subject,
    required String message,
  }) async {
    final userId = await tokenStorage.getResolvedUserId();
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    if (subject.trim().isEmpty) {
      throw Exception('문의 제목을 입력해주세요.');
    }
    if (message.trim().isEmpty) {
      throw Exception('문의 내용을 입력해주세요.');
    }

    if (supabase != null) {
      await supabase!.from('support_inquiries').insert({
        'user_id': userId.trim(),
        'category': category.trim().isEmpty ? 'GENERAL' : category.trim(),
        'subject': subject.trim(),
        'message': message.trim(),
      });
      return;
    }

    await dio.post(
      '/api/support/inquiries',
      data: {
        'userId': userId.trim(),
        'category': category.trim().isEmpty ? 'GENERAL' : category.trim(),
        'subject': subject.trim(),
        'message': message.trim(),
      },
    );
  }
}

final supportInquiryRepositoryProvider = Provider<SupportInquiryRepository>((
  ref,
) {
  return SupportInquiryRepository(
    dio: ref.read(dioProvider),
    tokenStorage: ref.read(tokenStorageProvider),
    supabase: ref.read(supabaseClientProvider),
  );
});
