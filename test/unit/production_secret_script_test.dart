import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production secret configurator covers AI and store secrets safely', () {
    final script = File(
      'scripts/configure_supabase_production_secrets.sh',
    ).readAsStringSync();

    expect(script, contains('OPENAI_API_KEY'));
    expect(script, contains('ANTHROPIC_API_KEY'));
    expect(script, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(script, contains('GOOGLE_PLAY_PACKAGE_NAME'));
    expect(script, contains('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
    expect(script, contains('APP_STORE_PRIVATE_KEY'));
    expect(script, contains('AI_ALBUM_DRAFT_PROVIDER'));
    expect(script, contains('AI_ALBUM_DRAFT_TIMEOUT_MS'));
    expect(script, contains('--env-file'));
    expect(script, contains('mktemp'));
    expect(script, contains('chmod 600'));
    expect(script, contains('trap'));
  });

  test(
    'production secret configurator does not pass secret values as cli args',
    () {
      final script = File(
        'scripts/configure_supabase_production_secrets.sh',
      ).readAsStringSync();

      expect(script, isNot(contains(r'"$name=$value"')));
      expect(
        script,
        isNot(contains(r'secrets set --project-ref "$PROJECT_REF" "$name=')),
      );
      expect(
        script,
        contains(
          r'secrets set --project-ref "$PROJECT_REF" --env-file "$ENV_FILE"',
        ),
      );
    },
  );

  test(
    'operations checklist references the interactive secret configurator',
    () {
      final doc = File(
        'docs/AI_ALBUM_OPERATIONS_CHECKLIST.md',
      ).readAsStringSync();

      expect(doc, contains('scripts/configure_supabase_production_secrets.sh'));
      expect(doc, contains('Do not paste'));
      expect(doc, contains('snapfit_points_2500'));
      expect(doc, contains('snapfit_points_8000'));
      expect(doc, contains('snapfit_points_18000'));
    },
  );
}
