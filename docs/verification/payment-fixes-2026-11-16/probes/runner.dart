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
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/print_order_checkout_test.dart' as checkout;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/point_purchase_service_test.dart' as iap;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/point_purchase_apple_finish_timeout_test.dart' as apple;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/print_payment_service_test.dart' as printservice;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/print_checkout_consent_test.dart' as consent;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/point_payment_repositories_test.dart' as repositories;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/point_shop_purchase_flow_test.dart' as shop;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/billing_responsive_refinement_test.dart' as responsive;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/unit/point_purchase_uncertainty_test.dart' as uncertainty;
import 'capture_points.dart' as cap_points;
import 'capture_checkout.dart' as cap_checkout;
class _AuditBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> main() async {
  final declarer = Declarer();

  declarer.declare(() {
    final name=Platform.environment['AUDIT_SUITE']!;
    group(name, {'checkout':checkout.main,'iap':iap.main,'apple':apple.main,'printservice':printservice.main,'consent':consent.main,'repositories':repositories.main,'shop':shop.main,'responsive':responsive.main,'uncertainty':uncertainty.main,'cap_points':cap_points.main,'cap_checkout':cap_checkout.main,}[name]!);
  });
  final pattern = RegExp(Platform.environment['SNAPFIT_TEST_FILTER'] ?? '.*');
  final suite = Suite(
    declarer.build(),
    SuitePlatform(Runtime.vm),
  ).filter((test) => pattern.hasMatch(test.name));
  TestWidgetsFlutterBinding.ensureInitialized();
  final a=Platform.environment['AUDIT_ASSETS']!;
  final paths=jsonDecode(File('$a/paths.json').readAsStringSync()) as List;
  final data=const StandardMessageCodec().encodeMessage({for(final p in paths) p:[{'asset':p}]})!;
  File('$a/AssetManifest.bin').writeAsBytesSync(data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes));
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
