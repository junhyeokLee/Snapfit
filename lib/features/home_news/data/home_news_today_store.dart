import 'package:shared_preferences/shared_preferences.dart';

/// A local copy makes the person's choice effective immediately, including
/// when saving the same choice to the server temporarily fails.
abstract interface class HomeNewsTodayStore {
  Future<DateTime?> readUntil(String owner);
  void rememberUntil(String owner, DateTime until);
  Future<void> persistUntil(String owner, DateTime until);
}

class PreferencesHomeNewsTodayStore implements HomeNewsTodayStore {
  final _memory = <String, DateTime>{};
  final _writes = <String, Future<void>>{};
  static String key(String owner) => 'snapfit_home_news_hidden_until_v1:$owner';

  @override
  Future<DateTime?> readUntil(String owner) async {
    final remembered = _memory[owner];
    if (remembered != null) return remembered;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      // A tap made while storage was loading has precedence over older data.
      final current = _memory[owner];
      if (current != null) return current;
      final value = preferences.getString(key(owner));
      if (value == null || !value.endsWith('Z')) return null;
      final until = DateTime.tryParse(value)?.toUtc();
      if (until != null) _memory[owner] = until;
      return until;
    } catch (_) {
      return _memory[owner];
    }
  }

  @override
  void rememberUntil(String owner, DateTime until) {
    final next = until.toUtc();
    final current = _memory[owner];
    if (current == null || next.isAfter(current)) _memory[owner] = next;
  }

  @override
  Future<void> persistUntil(String owner, DateTime until) {
    rememberUntil(owner, until);
    final write = (_writes[owner] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          final preferences = await SharedPreferences.getInstance();
          final latest = _memory[owner]!;
          if (!await preferences.setString(
            key(owner),
            latest.toIso8601String(),
          )) {
            throw StateError('오늘의 새 소식 숨김 설정을 저장하지 못했어요.');
          }
        });
    _writes[owner] = write;
    return write.whenComplete(() {
      if (identical(_writes[owner], write)) _writes.remove(owner);
    });
  }
}

/// Midnight in Korea, expressed as a UTC instant. The supplied time is from
/// the server, rather than the device's calendar or timezone.
DateTime homeNewsNextKoreanMidnight(DateTime serverNow) {
  final korean = serverNow.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(
    korean.year,
    korean.month,
    korean.day + 1,
  ).subtract(const Duration(hours: 9));
}
