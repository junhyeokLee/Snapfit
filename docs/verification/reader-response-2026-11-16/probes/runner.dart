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


import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/reader_first_interaction_test.dart' as reader_first_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/book_flip_progressive_entry_test.dart' as progressive_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/reader_paper_motion_test.dart' as paper_motion_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/reader_controller_lifecycle_test.dart' as reader_lifecycle_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/reader_navigation_continuity_test.dart' as reader_navigation_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/reader_image_capture_test.dart' as reader_images_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/reader_thumbnail_performance_test.dart' as reader_thumbnails_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/reader_image_quality_test.dart' as image_quality_tests;

import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/reader_thumbnail_layout_test.dart' as thumbnail_layout_tests;

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
        'paper_motion': paper_motion_tests.main,
        'reader_lifecycle': reader_lifecycle_tests.main,
        'reader_navigation': reader_navigation_tests.main,
        'reader_images': reader_images_tests.main,
        'reader_thumbnails': reader_thumbnails_tests.main,
        'image_quality': image_quality_tests.main,
        'thumbnail_layout': thumbnail_layout_tests.main,
        'reader_first': reader_first_tests.main,
        'progressive': progressive_tests.main,
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
