import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 로그인 없이도 기기(설치) 단위로 고정되는 user_id
/// - 최초 1회 UUID 생성 후 로컬에 저장
/// - 이후 동일 값 재사용
class UserIdService {
  static const _storageKey = 'snapfit_user_id';
  static const _uuid = Uuid();

  Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = _uuid.v4();
    await prefs.setString(_storageKey, created);
    return created;
  }
}

