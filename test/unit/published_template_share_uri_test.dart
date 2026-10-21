import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/presentation/utils/published_template_share_uri.dart';

void main() {
  final template = publishedCreationTemplates.first;

  test('public links strip auth queries, fragments and URL credentials', () {
    final link = publishedTemplateShareUri(
      template.id,
      webBase: Uri.parse(
        'https://private-user:password@snapfit.example/app/?code=secret&auth_callback=1#/login?access_token=secret',
      ),
    )!;
    expect(
      link.toString(),
      'https://snapfit.example/app/#/designs/templates/${template.id}',
    );
    expect(link.hasQuery, isFalse);
    expect(link.userInfo, isEmpty);
  });

  test('local web preview keeps the current host and port', () {
    final link = publishedTemplateShareUri(
      template.id,
      webBase: Uri.parse('http://127.0.0.1:7357/'),
    )!;
    expect(link.host, '127.0.0.1');
    expect(link.port, 7357);
    expect(link.fragment, '/designs/templates/${template.id}');
  });

  test('native links use the configured existing public hosting site', () {
    final link = publishedTemplateShareUri(template.id)!;
    expect(link.scheme, 'https');
    expect(link.host, 'snapfit-c719d.web.app');
    expect(link.fragment, '/designs/templates/${template.id}');
  });

  test('unpublished IDs and unsupported website schemes cannot form links', () {
    expect(publishedTemplateShareUri(9007199254740991), isNull);
    expect(
      publishedTemplateShareUri(
        template.id,
        webBase: Uri.parse('file:///private/app'),
      ),
      isNull,
    );
    expect(
      publishedTemplateShareUri(
        template.id,
        webBase: Uri.parse('javascript:alert(1)'),
      ),
      isNull,
    );
  });
}
