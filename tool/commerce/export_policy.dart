import 'dart:convert';
import 'dart:io';
import 'package:snap_fit/core/commerce/commerce_policy.dart';

/// Frozen public documents used by the server's immutable consent evidence.
/// Contains no registered-business assertion or private customer data.
void main() {
  stdout.writeln(
    jsonEncode({
      'bundleVersion': 'v1.0-prelaunch-20261019',
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
