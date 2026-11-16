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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_moment_summary_test.dart' as summary;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_monthly_completion_layout_test.dart' as monthly;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_screen_test.dart' as home;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_album_chrome_test.dart' as chrome;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/home_book_depth_test.dart' as depth;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/first_home_guide_test.dart' as guide;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/first_visit_flow_test.dart' as firstflow;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/moments_screens_test.dart' as records;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/moments_retention_layout_test.dart' as retention;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/moment_draft_entry_navigation_test.dart' as draft;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/moment_calendar_photo_choices_test.dart' as choices;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/moment_monthly_album_entry_test.dart' as albumEntry;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/creation_entry_routes_test.dart' as creationRoutes;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/album_creation_entry_test.dart' as creationEntry;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/unified_album_entry_test.dart' as creationJourney;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/moments_reward_flow_test.dart' as reward;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/moment_photo_format_display_test.dart' as format;
import '/tmp/snapfit-home-cleanup-captures.dart' as captures;
Future<void> main() async {
  final declarer = Declarer();
  final name = Platform.environment['SNAPFIT_TEST_SUITE'] ?? 'settings';
  final initialize = {'summary':summary.main,'monthly':monthly.main,'home':home.main,'chrome':chrome.main,'depth':depth.main,'guide':guide.main,'firstflow':firstflow.main,'records':records.main,'retention':retention.main,'draft':draft.main,'choices':choices.main,'albumEntry':albumEntry.main,'creationRoutes':creationRoutes.main,'creationEntry':creationEntry.main,'creationJourney':creationJourney.main,'reward':reward.main,'format':format.main,'captures':captures.main}[name]!;
  declarer.declare(() { group(name, initialize); });
  final pattern = RegExp(Platform.environment['SNAPFIT_TEST_FILTER'] ?? '.*');
  final suite = Suite(declarer.build(), SuitePlatform(Runtime.vm)).filter((test) => pattern.hasMatch(test.name));
  TestWidgetsFlutterBinding.ensureInitialized();
  await AssetManifest.loadFromAssetBundle(rootBundle);
  if(name=='firstflow') {
    goldenFileComparator=LocalFileComparator(Uri.file('/Users/devsheep/SnapFit/SnapFit/test/widget/first_visit_flow_test.dart'));
    autoUpdateGoldenFiles=Platform.environment['SNAPFIT_UPDATE_GOLDEN']=='true';
  }
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
