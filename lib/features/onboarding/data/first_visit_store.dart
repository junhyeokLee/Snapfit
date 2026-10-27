import 'package:shared_preferences/shared_preferences.dart';

/// Device-scoped, deliberately independent of account and album caches.
abstract interface class FirstVisitStore {
  Future<int> read();
  Future<void> write(int flags);
}

class PreferencesFirstVisitStore implements FirstVisitStore {
  static const key = 'snapfit_first_visit_v1';

  @override
  Future<int> read() async =>
      (await SharedPreferences.getInstance()).getInt(key) ?? 0;

  @override
  Future<void> write(int flags) async {
    if (!await (await SharedPreferences.getInstance()).setInt(key, flags)) {
      throw StateError('Could not save first-visit preferences');
    }
  }
}
