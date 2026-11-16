import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 설치된 video_player의 플랫폼 경계만 대체하는 테스트용 인터페이스다.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

enum AuthVideoState { initialized, failed, loading }

/// 영상 프레임을 검증하지 않고 실제 컨트롤러의 초기화 상태만 제어한다.
class AuthVideoPlatformFake extends video_platform.VideoPlayerPlatform {
  AuthVideoPlatformFake(this.state);
  final AuthVideoState state;
  final streams = <int, StreamController<video_platform.VideoEvent>>{};
  final played = <int>[];
  final disposed = <int>[];
  int creates = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(
    video_platform.VideoCreationOptions options,
  ) async {
    final id = ++creates;
    final events = streams[id] = StreamController<video_platform.VideoEvent>();
    if (state == AuthVideoState.initialized) {
      events.add(
        video_platform.VideoEvent(
          eventType: video_platform.VideoEventType.initialized,
          duration: const Duration(minutes: 1),
          size: const Size(390, 844),
        ),
      );
    } else if (state == AuthVideoState.failed) {
      events.addError(
        PlatformException(
          code: 'VideoError',
          message: 'fixture video unavailable',
        ),
      );
    }
    return id;
  }

  @override
  Stream<video_platform.VideoEvent> videoEventsFor(int id) =>
      streams[id]!.stream;
  @override
  Future<void> setLooping(int id, bool looping) async {}
  @override
  Future<void> setVolume(int id, double volume) async {}
  @override
  Future<void> play(int id) async => played.add(id);
  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildViewWithOptions(video_platform.VideoViewOptions options) =>
      const SizedBox.expand();

  @override
  Future<void> dispose(int id) async {
    disposed.add(id);
    final events = streams.remove(id);
    if (events != null) await events.close();
  }
}
