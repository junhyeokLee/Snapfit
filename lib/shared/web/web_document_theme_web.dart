import 'package:web/web.dart' as web;

void syncWebDocumentTheme(bool dark) {
  final background = dark ? '#111719' : '#F7F5F2';
  final scheme = dark ? 'dark' : 'light';
  final root = web.document.documentElement as web.HTMLElement?;
  if (root?.getAttribute('data-snapfit-theme') == scheme) return;
  root?.setAttribute('data-snapfit-theme', scheme);
  root?.style.setProperty('color-scheme', scheme);
  root?.style.setProperty('--snapfit-web-background', background);
  web.document.querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', background);
}
