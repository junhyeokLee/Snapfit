import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/snapfit_motion.dart';

void main() {
  test('snapFitAlbumOpenRoute uses premium non-zero album opening motion', () {
    final route = snapFitAlbumOpenRoute<void>(page: const SizedBox.shrink());

    expect(route.transitionDuration, const Duration(milliseconds: 520));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 260));
  });
}
