// Temporary in-process runner: use the installed test_api invoker without a
// reporter server. The same committed test bodies and widget binding run here.
import 'dart:async';
import 'dart:io';
import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/suite.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_api/src/backend/test.dart';
import 'package:flutter_test/flutter_test.dart' show group;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/home_view_model_test.dart' as home;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/social_profile_reliability_test.dart' as reliability;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/social_profile_screens_test.dart' as screens;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/social_profile_personal_area_test.dart' as profile;
import 'file:///Users/devsheep/SnapFit/SnapFit/docs/verification/profile-shared-albums-2026-11-12/probes/native_capture.dart' as captures;
Future<void> main() async {
  final declarer = Declarer();
  final name = Platform.environment['SNAPFIT_TEST_SUITE'] ?? 'settings';
  final initialize = {'profile': profile.main, 'captures': captures.main, 'home': home.main, 'reliability': reliability.main, 'screens': screens.main}[name]!;
  declarer.declare(() { group(name, initialize); });
  final pattern = RegExp(Platform.environment['SNAPFIT_TEST_FILTER'] ?? '.*');
  final suite = Suite(declarer.build(), SuitePlatform(Runtime.vm)).filter((test) => pattern.hasMatch(test.name));
  TestWidgetsFlutterBinding.ensureInitialized();
  await AssetManifest.loadFromAssetBundle(rootBundle);
  var passed = 0;
  var failed = 0;
  var skipped = 0;
  Future<bool> run(Test test, List<Group> groups, {bool count = true}) async {
    var isSkipped = test.metadata.skip;
    var skipReason = test.metadata.skipReason;
    for (final group in groups) {
      if (group.metadata.skip) {
        isSkipped = true;
        skipReason ??= group.metadata.skipReason;
      }
    }
    if (count && isSkipped) {
      skipped++;
      stdout.writeln('SKIP ${test.name}: ${skipReason ?? "platform scope"}');
      return true;
    }
    final live = test.load(suite, groups: groups);
    final errors = live.onError.listen((error) => stderr.writeln('$error'));
    final messages = live.onMessage.listen((message) => stdout.writeln(message.text));
    await live.run();
    await live.close();
    final ok = live.state.result.isPassing && live.errors.isEmpty;
    if (count) {
      if (ok) { passed++; } else { failed++; }
      stdout.writeln('${ok ? 'PASS' : 'FAIL'} ${test.name}');
    }
    await errors.cancel();
    await messages.cancel();
    return ok;
  }
  Future<void> visit(Group group, List<Group> parents) async {
    final groups = [...parents, group];
    final setup = group.setUpAll;
    final ready = setup == null || await run(setup, groups, count: false);
    if (ready) {
      for (final entry in group.entries) {
        if (entry is Group) { await visit(entry, groups); }
        if (entry is Test) { await run(entry, groups); }
      }
    } else { failed++; }
    final teardown = group.tearDownAll;
    if (teardown != null && !await run(teardown, groups, count: false)) failed++;
  }
  await Invoker.guard(() async { await visit(suite.group, []); });
  stdout.writeln('RESULT passed=$passed failed=$failed skipped=$skipped');
  exit(failed == 0 ? 0 : 1);
}
