import '../../../domain/entities/layer.dart';

class _CoverCopyChange {
  const _CoverCopyChange(this.id, this.index, this.before, this.after);
  final String id, before, after;
  final int index;
}

/// Carries only authored words between size variants, never their geometry.
class CoverCopyChanges {
  CoverCopyChanges.fromValues(
    List<LayerModel> original,
    Map<String, String> values,
  ) {
    final text = original
        .where((layer) => layer.type == LayerType.text)
        .toList();
    _textCount = text.length;
    _changes = [
      for (var index = 0; index < text.length; index++)
        if (values.containsKey(text[index].id) &&
            values[text[index].id] != (text[index].text ?? ''))
          _CoverCopyChange(
            text[index].id,
            index,
            text[index].text ?? '',
            values[text[index].id]!,
          ),
    ];
  }

  late final int _textCount;
  late final List<_CoverCopyChange> _changes;
  bool get isEmpty => _changes.isEmpty;

  List<LayerModel> applyTo(List<LayerModel> layers) {
    if (isEmpty) return layers;
    final text = layers.where((layer) => layer.type == LayerType.text).toList();
    final assigned = <int, _CoverCopyChange>{};
    final remaining = [..._changes];
    void assign(_CoverCopyChange change, int index) {
      assigned[index] = change;
      remaining.remove(change);
    }

    for (final change in [...remaining]) {
      final index = text.indexWhere((layer) => layer.id == change.id);
      if (index >= 0 && !assigned.containsKey(index)) assign(change, index);
    }
    for (final change in [...remaining]) {
      final index = text.indexWhere(
        (layer) =>
            (layer.text ?? '') == change.before &&
            !assigned.containsKey(text.indexOf(layer)),
      );
      if (index >= 0) assign(change, index);
    }
    // Legacy variants can use different IDs. Their ordered text roles are a
    // fallback only when both covers contain the same number of text fields.
    if (text.length == _textCount) {
      for (final change in [...remaining]) {
        if (!assigned.containsKey(change.index)) assign(change, change.index);
      }
    }
    var textIndex = 0;
    return [
      for (final layer in layers)
        if (layer.type != LayerType.text)
          layer
        else if (assigned[textIndex++] case final change?)
          layer.copyWith(text: change.after, isTemplateContent: false)
        else
          layer,
    ];
  }

  List<List<LayerModel>> applyToPages(List<List<LayerModel>> pages) =>
      pages.isEmpty ? pages : [applyTo(pages.first), ...pages.skip(1)];
}
