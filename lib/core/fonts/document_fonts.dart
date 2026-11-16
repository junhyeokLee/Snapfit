import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'document_font_manifest.dart';
import 'document_font_assets.dart';

typedef DocumentFontRegistrar =
    Future<void> Function(String family, List<Future<ByteData>> assets);

/// Shares in-flight work without retaining font bytes or failed futures.
/// Dependencies are injectable so retry and overlapping families can be tested
/// without contacting a customer account or a font server.
class DocumentFontRegistry {
  DocumentFontRegistry({
    required Iterable<Map<String, dynamic>> declarations,
    required Future<ByteData> Function(String path) loadAsset,
    required DocumentFontRegistrar register,
    Iterable<String> readyFamilies = const [],
    this.assetTimeout = const Duration(seconds: 25),
    this.registrationTimeout = const Duration(seconds: 12),
  }) : _entries = {
         for (final entry in declarations) entry['family'] as String: entry,
       },
       _loadAsset = loadAsset,
       _register = register,
       _ready = {...readyFamilies};

  final Map<String, Map<String, dynamic>> _entries;
  final Future<ByteData> Function(String path) _loadAsset;
  final DocumentFontRegistrar _register;
  final Duration assetTimeout;
  final Duration registrationTimeout;
  final Set<String> _ready;
  final _pending = <String, Future<void>>{};
  final _pendingAssets = <String, Future<ByteData>>{};
  final _attempts = <String, Object>{};

  bool areReady(Iterable<String> families) => families.every(
    (family) => !_entries.containsKey(family) || _ready.contains(family),
  );
  bool get allReady => areReady(_entries.keys);
  Future<void> ensureAll() => ensure(_entries.keys);
  void markLoaded(String family) => _ready.add(family);

  Future<void> ensure(Iterable<String> families) => Future.wait<void>([
    for (final family in families.toSet())
      if (_entries.containsKey(family) && !_ready.contains(family))
        _pending[family] ??= Future<void>.microtask(() => _load(family)),
  ], eagerError: true).then<void>((_) {});

  Future<ByteData> _asset(String path) {
    final pending = _pendingAssets[path];
    if (pending != null) return pending;
    late final Future<ByteData> request;
    request = Future<ByteData>.microtask(() => _loadAsset(path))
        .timeout(assetTimeout)
        .then((data) {
          if (data.lengthInBytes < 12 ||
              !const {
                0x00010000,
                0x4F54544F,
                0x74727565,
                0x74746366,
              }.contains(data.getUint32(0))) {
            throw const FormatException('Document font bytes are unavailable');
          }
          return data;
        })
        .whenComplete(() {
          // An uncancellable browser GET may finish after retry has started.
          // Only this attempt may release its own shared asset request.
          if (identical(_pendingAssets[path], request)) {
            _pendingAssets.remove(path);
          }
        });
    _pendingAssets[path] = request;
    return request;
  }

  Future<void> _load(String family) async {
    final attempt = Object();
    _attempts[family] = attempt;
    try {
      // Fetch/validate every face first. A registrar is never asked to register
      // an incomplete family, and one stalled GET cannot poison future retries.
      final faces = await Future.wait([
        for (final font in _entries[family]!['fonts'] as List)
          _asset((font as Map)['asset'] as String),
      ], eagerError: true);
      await Future<void>.sync(
        () => _register(family, [
          // Registrars use Future.wait; preserve its asynchronous Future
          // contract instead of invoking callbacks synchronously on iteration.
          for (final data in faces) Future<ByteData>.value(data),
        ]),
      ).timeout(registrationTimeout);
      // Engine registration itself cannot be canceled. A late completion uses
      // the same immutable originals, but must not unlock a later UI attempt.
      if (identical(_attempts[family], attempt)) _ready.add(family);
    } finally {
      if (identical(_attempts[family], attempt)) {
        _attempts.remove(family);
        _pending.remove(family);
      }
    }
  }
}

/// Only the web release packager opts into deferring document fonts. Native
/// builds and ordinary test bundles retain Flutter's complete font manifest.
abstract final class DocumentFonts {
  static const deferred =
      kIsWeb &&
      bool.fromEnvironment('SNAPFIT_DEFER_DOCUMENT_FONTS', defaultValue: false);

  /// UI lettering must remain ready before the first frame, including the
  /// onboarding lockup, login lockup and album-list header.
  static const startupFamilies = {
    'NotoSans',
    'Roboto',
    'Poppins',
    'Raleway',
    'MaterialIcons',
    'CupertinoIcons',
    'packages/cupertino_icons/CupertinoIcons',
  };

  static final List<Map<String, dynamic>> sourceDeclarations =
      List.unmodifiable(
        (jsonDecode(documentFontManifestJson) as List).map(
          (entry) => Map<String, dynamic>.from(entry as Map),
        ),
      );
  static final Map<String, String> immutableAssetPaths = Map.unmodifiable(
    Map<String, String>.from(jsonDecode(documentFontAssetPathsJson) as Map),
  );
  static final List<Map<String, dynamic>> declarations = deferred
      ? List.unmodifiable([
          for (final entry in sourceDeclarations)
            {
              ...entry,
              'fonts': [
                for (final font in entry['fonts'] as List)
                  {
                    ...Map<String, dynamic>.from(font as Map),
                    'asset':
                        immutableAssetPaths[font['asset']] ??
                        (throw StateError('Unversioned document font asset')),
                  },
              ],
            },
        ])
      : sourceDeclarations;
  static final _registry = DocumentFontRegistry(
    declarations: declarations,
    readyFamilies: startupFamilies,
    loadAsset: rootBundle.load,
    register: (family, assets) async {
      final bytes = await Future.wait(assets);
      final loader = FontLoader(family);
      for (final data in bytes) loader.addFont(SynchronousFuture(data));
      await loader.load();
    },
  );

  static bool areReady(Iterable<String> families) =>
      !deferred || _registry.areReady(families);

  static bool get allReady => !deferred || _registry.allReady;

  /// Unknown legacy family names keep their existing Flutter fallback policy.
  /// Known document families never paint or measure against a temporary font.
  static Future<void> ensure(Iterable<String> families) {
    if (!deferred) return SynchronousFuture(null);
    return _registry.ensure(families);
  }

  static Future<void> ensureAll() =>
      deferred ? _registry.ensureAll() : SynchronousFuture(null);

  /// Print/publication already validate and register their fonts explicitly.
  /// Let canvas gates know they are ready before the synchronous capture tree.
  static void markLoaded(String family) {
    if (deferred) _registry.markLoaded(family);
  }
}

/// The release keeps the complete manifest at this historical URL. Only the
/// engine's bootstrap request is redirected to the small interface manifest;
/// exporters, publication and older open tabs retain their complete hash paths.
Future<List<Map<String, dynamic>>> loadDocumentFontManifest() async {
  final current =
      (jsonDecode(
                await rootBundle.loadString('FontManifest.json', cache: false),
              )
              as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
  return current;
}
