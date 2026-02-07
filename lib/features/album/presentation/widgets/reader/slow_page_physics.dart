import 'package:flutter/material.dart';

/// PageView 스와이프를 느리게 만들어 부드러운 넘김 느낌을 줌
class SlowPagePhysics extends PageScrollPhysics {
  const SlowPagePhysics({super.parent});

  @override
  SlowPagePhysics applyTo(ScrollPhysics? ancestor) {
    return SlowPagePhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return super.applyPhysicsToUserOffset(position, offset * 0.1);
  }
}
