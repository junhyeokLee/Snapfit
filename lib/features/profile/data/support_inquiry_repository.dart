import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interceptors/token_storage.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../domain/support_inquiry.dart';

class SupportInquiryRepository {
  SupportInquiryRepository({required this.tokenStorage, this.supabase});

  final TokenStorage tokenStorage;
  final SupabaseClient? supabase;

  String? get currentUserId => supabase?.auth.currentUser?.id;

  Stream<String?> get authChanges =>
      supabase?.auth.onAuthStateChange.map((event) => event.session?.user.id) ??
      const Stream<String?>.empty();

  /// 토큰 조회를 기다리는 동안의 A → B → A도 별도 세션으로 취급한다.
  Future<T> _forOwner<T>(
    String ownerId,
    Future<T> Function(SupabaseClient client) operation,
  ) async {
    final client = supabase;
    if (client == null) {
      throw StateError('Supabase 고객문의 환경이 준비되지 않았습니다.');
    }
    if (ownerId.isEmpty || currentUserId != ownerId) {
      throw StateError('계정이 변경됐어요. 현재 계정의 고객센터를 다시 열어 주세요.');
    }
    var changed = false;
    final subscription = authChanges.listen((owner) {
      if (owner != ownerId) changed = true;
    }, onError: (Object _, StackTrace __) => changed = true);

    Future<void> check() async {
      if (changed || currentUserId != ownerId) {
        throw StateError('계정이 변경됐어요. 현재 계정의 고객센터를 다시 열어 주세요.');
      }
      final resolved = await tokenStorage.getResolvedUserId();
      if (changed || currentUserId != ownerId || resolved?.trim() != ownerId) {
        throw StateError('계정이 변경됐어요. 현재 계정의 고객센터를 다시 열어 주세요.');
      }
    }

    try {
      await check();
      final result = await operation(
        client,
      ).timeout(const Duration(seconds: 25));
      await check();
      return result;
    } catch (_) {
      // 이전 세션의 오류 응답도 현재 계정의 결과로 전달하지 않는다.
      await check();
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  Future<SupportInquiryPage> fetchMyInquiries({
    required String ownerId,
    int? beforeId,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 50 || beforeId != null && beforeId <= 0) {
      throw ArgumentError('문의 목록의 페이지 범위를 확인해 주세요.');
    }
    return _forOwner(ownerId, (client) async {
      var query = client
          .from('support_inquiries')
          .select('id,user_id,category,subject,message,status,created_at')
          .eq('user_id', ownerId);
      if (beforeId != null) query = query.lt('id', beforeId);
      final rows = await query.order('id', ascending: false).limit(limit + 1);
      final items = rows.map(SupportInquiry.fromJson).toList();
      if (items.length > limit + 1) {
        throw StateError('문의 목록의 페이지 범위를 확인하지 못했어요.');
      }
      // 서버의 본인 조회 정책과 별개로, 응답의 소유자·커서 경계를 확인한다.
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        if (item.userId != ownerId ||
            beforeId != null && item.id >= beforeId ||
            index > 0 && items[index - 1].id <= item.id) {
          throw StateError('문의 목록을 확인하지 못했어요. 다시 시도해 주세요.');
        }
      }
      return SupportInquiryPage(
        items: List<SupportInquiry>.unmodifiable(items.take(limit)),
        hasMore: items.length > limit,
      );
    });
  }

  Future<void> createInquiry({
    required String category,
    required String subject,
    required String message,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    if (subject.trim().isEmpty) {
      throw Exception('문의 제목을 입력해주세요.');
    }
    if (message.trim().isEmpty) {
      throw Exception('문의 내용을 입력해주세요.');
    }

    await _forOwner(userId, (client) async {
      await client.from('support_inquiries').insert({
        'user_id': userId.trim(),
        'category': category.trim().isEmpty ? 'GENERAL' : category.trim(),
        'subject': subject.trim(),
        'message': message.trim(),
      });
    });
  }
}

final supportInquiryRepositoryProvider = Provider<SupportInquiryRepository>((
  ref,
) {
  return SupportInquiryRepository(
    tokenStorage: ref.read(tokenStorageProvider),
    supabase: ref.read(supabaseClientProvider),
  );
});
