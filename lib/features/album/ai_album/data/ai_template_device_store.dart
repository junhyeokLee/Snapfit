import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/ai_album_models.dart';
import '../domain/ai_template_paper_tone.dart';
import '../domain/ai_template_text_edit.dart';

final aiTemplateDeviceStoreProvider = Provider((_) => AiTemplateDeviceStore());

/// Private memo and local text edits never leave this account-scoped device key.
/// No photographs, authentication tokens, rendered previews or network calls.
class AiTemplateDeviceStore {
  Future<void> _tail = Future.value();
  String _key(String owner) {
    if (owner.trim().isEmpty) throw ArgumentError('Missing owner');
    return 'snapfit_ai_design_v1_${base64Url.encode(utf8.encode(owner))}';
  }

  Future<Map<String, dynamic>?> load(String owner) async {
    await _tail;
    final raw = (await SharedPreferences.getInstance()).getString(_key(owner));
    if (raw == null) return null;
    if (utf8.encode(raw).length > 4 * 1024 * 1024)
      throw const FormatException('AI session too large');
    final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (value['version'] != 1)
      throw const FormatException('Invalid local AI session');
    return value;
  }

  Future<void> save(String owner, Map<String, Object?> value) {
    final encoded = jsonEncode({'version': 1, ...value});
    if (utf8.encode(encoded).length > 4 * 1024 * 1024)
      throw const FormatException('AI session too large');
    final operation = _tail.then((_) async {
      final saved = await (await SharedPreferences.getInstance()).setString(
        _key(owner),
        encoded,
      );
      if (!saved) throw StateError('Local AI session could not be saved');
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> remove(String owner) {
    final operation = _tail.then((_) async {
      await (await SharedPreferences.getInstance()).remove(_key(owner));
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }
}

Map<String, Object?> aiTemplateLocalEdits(
  AiTemplateDesign original,
  AiTemplateDesign edited,
) {
  var tone = AiTemplatePaperTone.original;
  for (final candidate in [
    AiTemplatePaperTone.warm,
    AiTemplatePaperTone.cool,
  ]) {
    final adjusted = withAiTemplatePaperTone(original, candidate);
    if (List.generate(
      original.pages.length,
      (index) =>
          adjusted.pages[index].background == edited.pages[index].background,
    ).every((same) => same)) {
      tone = candidate;
      break;
    }
  }
  final copy = <Map<String, Object>>[];
  for (final (pageIndex, page) in edited.pages.indexed) {
    for (final element in page.elements.where(
      (element) => element.kind == 'text',
    )) {
      final previous = original.pages[pageIndex].elements
          .where((before) => before.id == element.id)
          .firstOrNull;
      if (previous != null && previous.text != element.text) {
        copy.add({
          'page': pageIndex,
          'id': element.id,
          'text': element.text ?? '',
        });
      }
    }
  }
  return {'paperTone': tone.name, 'texts': copy};
}

AiTemplateDesign restoreAiTemplateLocalEdits(
  AiTemplateDesign original,
  Map edits,
) {
  var current = withAiTemplatePaperTone(
    original,
    AiTemplatePaperTone.values.byName(
      edits['paperTone'] as String? ?? 'original',
    ),
  );
  for (final raw in (edits['texts'] as List? ?? const [])) {
    if (raw is! Map) throw const FormatException('Invalid local text edit');
    final next = withAiTemplateText(
      current,
      pageIndex: raw['page'] as int,
      elementId: raw['id'] as String,
      text: raw['text'] as String,
    );
    if (next == null) throw const FormatException('Local copy requires review');
    current = next;
  }
  return current;
}
