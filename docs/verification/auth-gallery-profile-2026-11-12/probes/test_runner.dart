// 실제 테스트 본문을 직렬 실행한다. reporter 서버나 Flutter SDK 캐시 쓰기는 필요 없다.
import 'dart:async';
import 'dart:io';
import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/suite.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_api/src/backend/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/auth_recovery_completion_test.dart'
    as auth_completion;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/login_screen_test.dart'
    as login;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/social_profile_exit_guard_test.dart'
    as profile_exit;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/social_profile_screens_test.dart'
    as profile;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/social_profile_reliability_test.dart'
    as profile_reliability;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/gallery_empty_or_error_panel_test.dart'
    as gallery_panel;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/gallery_notifier_test.dart'
    as gallery_notifier;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/social_login_recovery_test.dart'
    as social_login;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/gallery_picker_refinement_test.dart'
    as gallery_picker;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/auth_entry_responsive_test.dart'
    as auth_responsive;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/settings_responsive_refinement_test.dart'
    as settings_responsive;
import 'native_capture.dart' as capture;

Future<void> main() async {
  final declarer = Declarer();
  final modules = <String, void Function()>{
    'capture': capture.main,
    'auth_completion': auth_completion.main,
    'login': login.main,
    'profile_exit': profile_exit.main,
    'profile': profile.main,
    'profile_reliability': profile_reliability.main,
    'gallery_panel': gallery_panel.main,
    'gallery_notifier': gallery_notifier.main,
    'social_login': social_login.main,
    'gallery_picker': gallery_picker.main,
    'auth_responsive': auth_responsive.main,
    'settings_responsive': settings_responsive.main,
  };
  final names =
      (Platform.environment['SNAPFIT_TEST_SUITE'] ??
              'auth_completion,login,profile_exit,profile,profile_reliability,gallery_panel,gallery_notifier,social_login')
          .split(',');
  declarer.declare(() {
    for (final name in names) {
      group(name, modules[name]!);
    }
  });
  final pattern = RegExp(Platform.environment['SNAPFIT_TEST_FILTER'] ?? '.*');
  final suite = Suite(
    declarer.build(),
    SuitePlatform(Runtime.vm),
  ).filter((test) => pattern.hasMatch(test.name));
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
    final messages = live.onMessage.listen(
      (message) => stdout.writeln(message.text),
    );
    await live.run();
    await live.close();
    final ok = live.state.result.isPassing && live.errors.isEmpty;
    if (count) {
      if (ok) {
        passed++;
      } else {
        failed++;
      }
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
        if (entry is Group) {
          await visit(entry, groups);
        }
        if (entry is Test) {
          await run(entry, groups);
        }
      }
    } else {
      failed++;
    }
    final teardown = group.tearDownAll;
    if (teardown != null && !await run(teardown, groups, count: false))
      failed++;
  }

  await Invoker.guard(() async {
    await visit(suite.group, []);
  });
  stdout.writeln('RESULT passed=$passed failed=$failed skipped=$skipped');
  exit(failed == 0 ? 0 : 1);
}
