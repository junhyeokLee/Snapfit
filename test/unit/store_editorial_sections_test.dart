import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_editorial_list.dart';

void main() {
  test(
    'compact discovery starts with three scannable rows without losing products',
    () {
      for (final columns in [2, 3, 4]) {
        for (var count = 0; count < 100; count++) {
          final rows = storeEditorialRows(
            count,
            columns: columns,
            compactStart: true,
          );
          expect(rows.expand((row) => row), List.generate(count, (i) => i));
          expect(
            rows.every((row) => row.isNotEmpty && row.length <= columns),
            isTrue,
          );
          for (final row in rows.take(
            count ~/ columns < 3 ? count ~/ columns : 3,
          )) {
            expect(row.length, columns);
          }
        }
      }
      expect(storeEditorialRows(8, compactStart: true), [
        [0, 1],
        [2, 3],
        [4, 5],
        [6],
        [7],
      ]);
    },
  );

  test('existing editorial callers keep their original row policy', () {
    expect(storeEditorialRows(8), [
      [0],
      [1, 2],
      [3, 4],
      [5],
      [6, 7],
    ]);
  });
}
