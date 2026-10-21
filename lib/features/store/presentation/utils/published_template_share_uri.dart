import '../../../../core/navigation/web_app_location.dart';
import '../../../album/data/bundled_creation_templates.dart';

// Native shares use the existing Firebase Hosting site. This can be overridden
// without changing the artwork catalog when the public website gets a domain.
const _publicWebsite = String.fromEnvironment(
  'PUBLIC_WEBSITE_URL',
  defaultValue: 'https://snapfit-c719d.web.app/',
);

/// Public artwork links contain only a canonical published template ID.
/// Rebuilding the URI deliberately excludes OAuth queries, credentials and the
/// current page's fragment. Web installations retain their hosting base path.
Uri? publishedTemplateShareUri(int templateId, {Uri? webBase}) {
  if (!publishedCreationTemplates.any((item) => item.id == templateId)) {
    return null;
  }
  final base = webBase ?? Uri.tryParse(_publicWebsite);
  if (base == null ||
      (base.scheme != 'https' && base.scheme != 'http') ||
      base.host.isEmpty) {
    return null;
  }
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: base.path.isEmpty ? '/' : base.path,
    fragment: WebAppLocation(WebAppPage.template, '$templateId').uri.toString(),
  );
}
