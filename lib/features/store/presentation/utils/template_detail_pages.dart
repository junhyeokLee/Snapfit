import 'dart:collection';

import 'package:flutter/painting.dart';

import '../../../../core/templates/data_template_engine.dart';
import '../../../album/domain/entities/layer.dart';

/// One budget shared by the default book and all of its aspect variants.
/// Browsing or zooming does not compile and retain the whole book.
class TemplateDetailPageCache {
  TemplateDetailPageCache({this.limit = 24}) : assert(limit > 0);

  final int limit;
  final _pages = LinkedHashMap<Object, List<LayerModel>>.identity();

  int get length => _pages.length;

  void clear() => _pages.clear();

  List<LayerModel> read(Object key, List<LayerModel> Function() compile) {
    final page = _pages.remove(key) ?? List<LayerModel>.unmodifiable(compile());
    _pages[key] = page;
    while (_pages.length > limit) {
      _pages.remove(_pages.keys.first);
    }
    return page;
  }
}

/// List-compatible so the detail, full-screen viewer and creation flow share
/// page sources. Only an indexed, visible page becomes native layer models.
class TemplateDetailPages extends ListBase<List<LayerModel>> {
  TemplateDetailPages({
    required List<Map<String, dynamic>> pages,
    required this.canvas,
    required this.cache,
  }) : _sources = List.of(pages, growable: false),
       _keys = List.generate(pages.length, (_) => Object(), growable: false);

  final List<Map<String, dynamic>> _sources;
  final List<Object> _keys;
  final Size canvas;
  final TemplateDetailPageCache cache;

  @override
  int get length => _sources.length;

  @override
  set length(int value) => throw UnsupportedError('Read-only template pages');

  @override
  List<LayerModel> operator [](int index) {
    final source = _sources[index];
    return cache.read(
      _keys[index],
      () => DataTemplateEngine.buildLayersFromJson({
        'strictLayout': true,
        'designWidth': canvas.width,
        'designHeight': canvas.height,
        'layers': source['layers'] ?? const [],
      }, canvas),
    );
  }

  @override
  void operator []=(int index, List<LayerModel> value) =>
      throw UnsupportedError('Read-only template pages');
}
