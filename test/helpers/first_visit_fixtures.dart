import 'package:snap_fit/features/onboarding/data/first_visit_store.dart';

class MemoryFirstVisitStore implements FirstVisitStore {
  MemoryFirstVisitStore([this.flags = 0]);
  int flags;
  int reads = 0;
  final writes = <int>[];

  @override
  Future<int> read() async {
    reads++;
    return flags;
  }

  @override
  Future<void> write(int next) async {
    writes.add(next);
    flags = next;
  }
}
