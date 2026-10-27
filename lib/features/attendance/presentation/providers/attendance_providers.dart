import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_status.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final repository = SupabaseAttendanceRepository(
    ref.watch(supabaseClientProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final attendanceSessionProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(attendanceRepositoryProvider);
  yield repository.currentUserId;
  yield* repository.authChanges;
});

final attendanceCurrentUserIdProvider = Provider<String?>((ref) {
  ref.watch(attendanceSessionProvider);
  return ref.watch(attendanceRepositoryProvider).currentUserId;
});

final attendanceStatusProvider = FutureProvider.autoDispose<AttendanceStatus>((
  ref,
) {
  ref.watch(attendanceSessionProvider);
  ref.watch(attendanceCurrentUserIdProvider);
  return ref.watch(attendanceRepositoryProvider).fetchStatus();
});
