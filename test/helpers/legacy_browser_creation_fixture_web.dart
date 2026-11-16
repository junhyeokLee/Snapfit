import 'dart:convert';
import 'dart:js_interop';

import 'package:snap_fit/features/album/data/browser_draft_database.dart';

Future<void> writeLegacyBrowserCreationDraft(
  String owner,
  Map<String, dynamic> metadata,
) => BrowserDraftDatabase().transaction<void>(
  owner: owner,
  write: true,
  action: (_, put, __) {
    put(
      {
            'owner': owner,
            'json': jsonEncode(metadata),
            'photos': <Object>[],
          }.jsify()
          as JSObject,
    );
  },
);
