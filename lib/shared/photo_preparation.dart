import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/widgets.dart';

/// Suspending is not a failed photo. No waiting futures, listeners or timers are
/// parked on a hidden page; its rasterizer resumes preparation when visible.
class PhotoPreparationPaused extends BookFlipPreparationPaused {
  const PhotoPreparationPaused();
}

bool photoPreparationActive(BuildContext context) {
  if (!context.mounted) return false;
  final lifecycle = WidgetsBinding.instance.lifecycleState;
  return TickerMode.of(context) &&
      (lifecycle == null || lifecycle == AppLifecycleState.resumed);
}

bool checkPhotoPreparationActive(BuildContext context) {
  if (!context.mounted) return false;
  if (!photoPreparationActive(context)) throw const PhotoPreparationPaused();
  return true;
}

/// Lazily mount local photo providers only while their route is visible and the
/// app is resumed. Hidden artwork retains no image stream or waiting callback.
class ActivePhoto extends StatefulWidget {
  const ActivePhoto({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<ActivePhoto> createState() => _ActivePhotoState();
}

class _ActivePhotoState extends State<ActivePhoto> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => photoPreparationActive(context)
      ? widget.builder(context)
      : const SizedBox.expand();
}
