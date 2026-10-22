import 'dart:async';

import 'support/golden_failure_output_stub.dart'
    if (dart.library.io) 'support/golden_failure_output_io.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  configureGoldenFailureOutput();
  await testMain();
}
