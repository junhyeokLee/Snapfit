import 'package:flutter/widgets.dart';

import '../../../domain/entities/album.dart';
import '../../utils/album_progress.dart';

/// Captions and cover dimensions share compact metadata. Callers keep artwork
/// stable for count-only changes. Hidden/unmounted consumers detach immediately.
class HomeAlbumProgressBuilder extends StatefulWidget {
  const HomeAlbumProgressBuilder({
    super.key,
    required this.album,
    required this.builder,
  });
  final Album album;
  final Widget Function(BuildContext, AlbumProgressInfo?) builder;

  @override
  State<HomeAlbumProgressBuilder> createState() =>
      _HomeAlbumProgressBuilderState();
}

class _HomeAlbumProgressBuilderState extends State<HomeAlbumProgressBuilder>
    with WidgetsBindingObserver {
  AlbumProgressInfo? _progress;
  AlbumProgressRequest? _request;
  ScrollPosition? _scrollPosition;
  int? _resumeFrame;
  bool _active = false;
  bool _foreground = true;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _scrollPosition)) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
      _scrollPosition = position;
      position?.isScrollingNotifier.addListener(_onScrollActivity);
    }
    _active = TickerMode.of(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant HomeAlbumProgressBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.album, widget.album)) {
      _cancel();
      _progress = null;
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (!mounted || foreground == _foreground) return;
    setState(() {
      _foreground = foreground;
      _sync();
    });
  }

  void _cancel() {
    _version++;
    final frame = _resumeFrame;
    if (frame != null) WidgetsBinding.instance.cancelFrameCallbackWithId(frame);
    _resumeFrame = null;
    _request?.cancel();
    _request = null;
  }

  void _sync() {
    if (!_active || !_foreground) {
      _cancel();
      return;
    }
    _progress ??= cachedAlbumProgress(widget.album);
    if (_progress != null || _request != null) return;
    if (_scrollPosition?.isScrollingNotifier.value == true) return;
    final version = ++_version;
    final request = AlbumProgressLoader.request(widget.album);
    _request = request;
    request.result.then((progress) {
      if (!mounted || version != _version || !_active || !_foreground) return;
      _request = null;
      if (progress != null) setState(() => _progress = progress);
    });
  }

  void _onScrollActivity() {
    if (_scrollPosition?.isScrollingNotifier.value == true) {
      if (_request != null || _resumeFrame != null) _cancel();
    } else if (mounted &&
        _active &&
        _foreground &&
        _progress == null &&
        _resumeFrame == null) {
      // Scroll activity may end during layout. Resume on the next frame rather
      // than calling setState from a metrics/layout notification.
      _resumeFrame = WidgetsBinding.instance.scheduleFrameCallback((_) {
        _resumeFrame = null;
        if (mounted &&
            _active &&
            _foreground &&
            _scrollPosition?.isScrollingNotifier.value != true)
          setState(_sync);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}
