// 후보 UI를 실제 위젯으로 직렬 재현한다. 보고서 서버나 SDK 캐시 쓰기는 필요 없다.
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

import 'dart:convert';


import 'file:///tmp/snapfit-visual-refresh-20261116/cap_home.dart' as cap_home_tests;
import 'file:///tmp/snapfit-visual-refresh-20261116/cap_account.dart' as cap_account_tests;
import 'file:///tmp/snapfit-visual-refresh-20261116/cap_store.dart' as cap_store_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/my_page_screen_test.dart' as account_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/template_detail_preview_hierarchy_test.dart' as store_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_moment_summary_test.dart' as home_summary_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_album_chrome_test.dart' as home_chrome_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/experience_detail_redesign_test.dart' as detail_existing_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/template_detail_screen_test.dart' as detail_screen_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_screen_test.dart' as home_screen_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/experience_navigation_test.dart' as navigation_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_album_paper_open_overlay_context_test.dart' as paper_context_tests;

class _AuditBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> main() async {
  if (Platform.environment['AUDIT_SUITE']!.startsWith('cap_')) _AuditBinding();
  final declarer = Declarer();

  declarer.declare(() {
    final name = Platform.environment['AUDIT_SUITE']!;
    group(
      name,
      {
        'account': account_tests.main,
        'store': store_tests.main,
        'home_summary': home_summary_tests.main,
        'home_chrome': home_chrome_tests.main,
        'detail_existing': detail_existing_tests.main,
        'detail_screen': detail_screen_tests.main,
        'home_screen': home_screen_tests.main,
        'navigation': navigation_tests.main,
        'paper_context': paper_context_tests.main,
        'cap_home': cap_home_tests.main,
        'cap_account': cap_account_tests.main,
        'cap_store': cap_store_tests.main,
      }[name]!,
    );
  });
  final pattern = RegExp(Platform.environment['SNAPFIT_TEST_FILTER'] ?? '.*');
  final suite = Suite(
    declarer.build(),
    SuitePlatform(Runtime.vm),
  ).filter((test) => pattern.hasMatch(test.name));
  TestWidgetsFlutterBinding.ensureInitialized();
  final a = Platform.environment['AUDIT_ASSETS']!;
  final paths = jsonDecode(File('$a/paths.json').readAsStringSync()) as List;
  final data = const StandardMessageCodec().encodeMessage({
    for (final p in paths)
      p: [
        {'asset': p},
      ],
  })!;
  File('$a/AssetManifest.bin').writeAsBytesSync(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
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
    stdout.writeln('${count ? 'START' : 'HOOK'} ${test.name}');
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
