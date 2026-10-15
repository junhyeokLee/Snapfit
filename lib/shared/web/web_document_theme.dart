import 'web_document_theme_stub.dart'
    if (dart.library.js_interop) 'web_document_theme_web.dart' as platform;

/// Match the browser chrome and page behind Flutter to the active website theme.
void syncWebDocumentTheme(bool dark) => platform.syncWebDocumentTheme(dark);
