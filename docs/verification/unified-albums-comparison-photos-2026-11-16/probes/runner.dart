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

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/album_collection_unified_test.dart' as library_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/store_comparison_continuity_test.dart' as store_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/browser_photo_selection_continuity_test.dart' as photos_tests;
import 'file:///tmp/snapfit-ux-applied-20261116/personal_probe.dart' as personal_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/store_hub_test.dart' as hub_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/store_filter_continuity_test.dart' as filters_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/template_design_comparison_test.dart' as comparison_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/template_comparison_journey_test.dart' as journey_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/template_comparison_price_refresh_test.dart' as price_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/browser_photo_selection_test.dart' as photo_old_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/album_members_screen_test.dart' as members_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/social_profile_personal_area_test.dart' as profile_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/browser_photo_import_test.dart' as imports_tests;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/browser_photo_storage_test.dart' as storage_tests;
import 'file:///tmp/snapfit-ux-applied-20261116/cap_library.dart' as cap_library_tests;
import 'file:///tmp/snapfit-ux-applied-20261116/cap_store.dart' as cap_store_tests;
import 'file:///tmp/snapfit-ux-applied-20261116/cap_create.dart' as cap_create_tests;

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
        'library': library_tests.main,
        'store': store_tests.main,
        'photos': photos_tests.main,
        'personal': personal_tests.main,
        'hub': hub_tests.main,
        'filters': filters_tests.main,
        'comparison': comparison_tests.main,
        'journey': journey_tests.main,
        'price': price_tests.main,
        'photo_old': photo_old_tests.main,
        'members': members_tests.main,
        'profile': profile_tests.main,
        'imports': imports_tests.main,
        'storage': storage_tests.main,
        'cap_library': cap_library_tests.main,
        'cap_store': cap_store_tests.main,
        'cap_create': cap_create_tests.main,
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
