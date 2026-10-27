import 'package:flutter/widgets.dart';

typedef SliverViewportDimensions = ({
  double crossAxisExtent,
  double viewportMainAxisExtent,
});

/// Adaptive grids depend on viewport geometry, not the current scroll offset.
/// Keep their delegates intact as SliverConstraints change during scrolling.
/// Data/callback updates and inherited dependencies still rebuild the sliver.
class ViewportSliverLayoutBuilder extends StatefulWidget {
  const ViewportSliverLayoutBuilder({super.key, required this.builder});

  final Widget Function(BuildContext, SliverViewportDimensions) builder;

  @override
  State<ViewportSliverLayoutBuilder> createState() =>
      _ViewportSliverLayoutBuilderState();
}

class _ViewportSliverLayoutBuilderState
    extends State<ViewportSliverLayoutBuilder> {
  SliverViewportDimensions? _dimensions;
  Widget? _sliver;

  @override
  void didUpdateWidget(covariant ViewportSliverLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sliver = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sliver = null;
  }

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (_, constraints) {
      final dimensions = (
        crossAxisExtent: constraints.crossAxisExtent,
        viewportMainAxisExtent: constraints.viewportMainAxisExtent,
      );
      if (_sliver == null || _dimensions != dimensions) {
        _dimensions = dimensions;
        // Register MediaQuery/Theme dependencies on this State's context so
        // didChangeDependencies invalidates the cached child as well.
        _sliver = widget.builder(context, dimensions);
      }
      return _sliver!;
    },
  );
}
