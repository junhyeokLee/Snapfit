import 'dart:convert';

import 'package:snap_fit/core/templates/retired_store_templates.dart';

/// Retired store documents must not be restored by an old export or handoff.
bool isRetiredStoreCatalogRow(Map<dynamic, dynamic> row) {
  final document = row['templateJson'] ?? row['template_json'];
  return RetiredStoreTemplates.matches(
    id: int.tryParse('${row['id']}'),
    title: row['title']?.toString(),
    templateId: row['templateId']?.toString(),
    templateJson: document is String
        ? document
        : document == null
        ? null
        : jsonEncode(document),
  );
}
