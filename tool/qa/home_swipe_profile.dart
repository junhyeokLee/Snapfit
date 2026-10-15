import 'dart:convert';
import 'dart:io';

// vm_service is supplied by the project's Flutter test toolchain.
// ignore: depend_on_referenced_packages
import 'package:vm_service/vm_service_io.dart';

/// Run against an unlocked, portrait Android device already showing Home.
/// This only swipes albums; it never taps a cover or saves album data.
Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError('Expected VM service URI, adb path, device serial.');
  }
  final uri = Uri.parse(args[0]);
  if (uri.host != '127.0.0.1' && uri.host != 'localhost') {
    throw ArgumentError('Only a locally forwarded VM service is allowed.');
  }
  final socket = uri.replace(scheme: 'ws', path: '${uri.path}ws');
  final service = await vmServiceConnectUri(socket.toString());
  final original = await service.getVMTimelineFlags();
  try {
    Future<void> swipe(bool forward) async {
      final result = await Process.run(args[1], [
        '-s',
        args[2],
        'shell',
        'input',
        'swipe',
        forward ? '900' : '180',
        '1000',
        forward ? '180' : '900',
        '1000',
        '350',
      ]);
      if (result.exitCode != 0) throw StateError('Android swipe failed.');
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    for (var i = 0; i < 4; i++) {
      await swipe(i.isEven);
    }
    await service.setVMTimelineFlags(['Dart', 'Embedder', 'GC']);
    await service.clearVMTimeline();
    for (var i = 0; i < 12; i++) {
      await swipe(i.isEven);
    }
    final timeline = await service.getVMTimeline();
    final events = timeline.traceEvents ?? [];
    final durations = <String, List<double>>{};
    final stacks = <String, List<Map<String, dynamic>>>{};
    for (final event in events) {
      final data = event.json ?? {};
      final thread = '${data['pid']}:${data['tid']}';
      final phase = data['ph'];
      final name = data['name'] as String? ?? '';
      final timestamp = (data['ts'] as num?)?.toDouble();
      if (phase == 'X') {
        final duration = (data['dur'] as num?)?.toDouble();
        if (duration != null) (durations[name] ??= []).add(duration / 1000);
      } else if (phase == 'B' && timestamp != null) {
        (stacks[thread] ??= []).add({'name': name, 'ts': timestamp});
      } else if (phase == 'E' &&
          timestamp != null &&
          (stacks[thread]?.isNotEmpty ?? false)) {
        final start = stacks[thread]!.removeLast();
        (durations[start['name']] ??= []).add(
          (timestamp - (start['ts'] as double)) / 1000,
        );
      }
    }
    Map<String, Object> stats(List<double> values) {
      values.sort();
      return {
        'samples': values.length,
        'medianMs': values[values.length ~/ 2],
        'p95Ms': values[((values.length - 1) * .95).floor()],
        'maxMs': values.last,
        'over16_67Ms': values.where((ms) => ms > 16.67).length,
        'over8_33Ms': values.where((ms) => ms > 8.33).length,
      };
    }

    final selected = durations.entries.where(
      (e) =>
          e.key == 'Frame' ||
          e.key.contains('Rasterizer') ||
          e.key == 'Animator::BeginFrame',
    );
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'mode': 'profile',
        'swipes': 12,
        'warmupSwipes': 4,
        'note':
            'Timeline CPU spans, not end-to-end presentation FPS. No pre-change baseline.',
        'spans': {for (final entry in selected) entry.key: stats(entry.value)},
      }),
    );
  } finally {
    await service.setVMTimelineFlags(original.recordedStreams ?? []);
    await service.dispose();
  }
}
