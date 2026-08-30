import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/snapfit_motion.dart';

void main() {
  test('SnapFitMotion exposes page turn tokens for editor interactions', () {
    expect(SnapFitMotion.pageTurn, const Duration(milliseconds: 390));
    expect(SnapFitMotion.pageTurnFast, const Duration(milliseconds: 220));
    expect(SnapFitMotion.pageTurnCurve, Curves.easeOutQuart);
    expect(SnapFitMotion.pageTurnExitCurve, Curves.easeInCubic);
  });

  test('snapFitAlbumOpenRoute uses premium non-zero album opening motion', () {
    final route = snapFitAlbumOpenRoute<void>(page: const SizedBox.shrink());

    expect(route.transitionDuration, const Duration(milliseconds: 420));
    expect(route.reverseTransitionDuration, SnapFitMotion.fast);
  });
}
