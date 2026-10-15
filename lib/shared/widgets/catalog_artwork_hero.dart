import 'package:flutter/material.dart';

/// The list artwork stays intact during flight, before the detail renderer takes over.
class CatalogArtworkHero extends StatelessWidget {
  const CatalogArtworkHero({super.key, required this.tag, required this.child});
  final Object? tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (tag == null || MediaQuery.disableAnimationsOf(context)) return child;
    return Hero(
      tag: tag!,
      flightShuttleBuilder: (_, __, direction, from, to) {
        final listHero =
            (direction == HeroFlightDirection.push ? from : to).widget as Hero;
        return Material(type: MaterialType.transparency, child: listHero.child);
      },
      child: child,
    );
  }
}
