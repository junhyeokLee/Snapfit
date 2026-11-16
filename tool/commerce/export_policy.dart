import 'dart:convert';
import 'dart:io';
import 'package:snap_fit/core/commerce/commerce_policy.dart';

/// Frozen public documents used by the server's immutable consent evidence.
/// Export a new bundle for each published revision; never replace old evidence.
void main() {
  stdout.writeln(
    jsonEncode({
      'bundleVersion': CommercePolicy.bundleVersion,
      'stage': 'PRELAUNCH',
      'documents': [
        for (final doc in CommercePolicy.documents)
          {
            'kind': doc.kind.name,
            'title': doc.title,
            'version': doc.version,
            'effectiveDate': doc.effectiveDate,
            'sections': [
              for (final section in doc.sections)
                {'heading': section.heading, 'content': section.content},
            ],
          },
      ],
    }),
  );
}
