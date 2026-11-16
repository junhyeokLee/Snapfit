import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Bounds only Supabase Auth's small JSON exchanges, including response bodies.
/// A stalled token refresh must fail inside GoTrue so its shared refresh future
/// is released. Timing out an individual screen leaves that SDK future stuck.
class AuthRequestHttpClient extends http.BaseClient {
  AuthRequestHttpClient({
    required String supabaseUrl,
    http.Client? inner,
    this.timeout = const Duration(seconds: 20),
  }) : _inner = inner ?? http.Client(),
       _authBase = Uri.parse(
         '${supabaseUrl.replaceFirst(RegExp(r'/+$'), '')}/auth/v1',
       );

  final http.Client _inner;
  final Uri _authBase;
  final Duration timeout;

  bool _isAuth(Uri url) =>
      url.hasScheme &&
      url.hasAuthority &&
      url.origin == _authBase.origin &&
      (url.path == _authBase.path || url.path.startsWith('${_authBase.path}/'));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Uploads, PostgREST streams, functions and third-party requests retain
    // their own lifetime and original request object. Do not buffer/clone them.
    if (!_isAuth(request.url) || request is! http.Request) {
      return _inner.send(request);
    }
    final payload = List<int>.of(request.bodyBytes);
    // Keep BaseClient's normal one-send contract for the caller's Request.
    request.finalize();
    final abort = Completer<void>();
    final externalAbort = request is http.Abortable
        ? (request as http.Abortable).abortTrigger
        : null;
    final forwarded =
        http.AbortableRequest(
            request.method,
            request.url,
            abortTrigger: externalAbort == null
                ? abort.future
                : Future.any<void>([abort.future, externalAbort]),
          )
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..persistentConnection = request.persistentConnection
          ..bodyBytes = payload
          ..headers.addAll(request.headers);

    final result = Completer<http.StreamedResponse>();
    StreamSubscription<List<int>>? body;
    final bytes = BytesBuilder(copy: false);
    late final Timer deadline;

    void cancelBody() {
      final subscription = body;
      body = null;
      if (subscription != null) {
        unawaited(subscription.cancel().catchError((Object _) {}));
      }
    }

    void stop() {
      deadline.cancel();
      if (!abort.isCompleted) abort.complete();
    }

    void fail(Object error, [StackTrace? stack]) {
      if (result.isCompleted) return;
      result.completeError(error, stack);
      stop();
      cancelBody();
      bytes.clear();
    }

    deadline = Timer(timeout, () {
      fail(
        http.ClientException('Authentication request timed out', request.url),
      );
    });

    unawaited(() async {
      try {
        final response = await _inner.send(forwarded);
        if (result.isCompleted) {
          // A custom transport may ignore abortTrigger. Never hand its late
          // token response back to GoTrue; release the unread body instead.
          unawaited(
            response.stream
                .listen((_) {}, onError: (Object _) {})
                .cancel()
                .catchError((Object _) {}),
          );
          return;
        }
        body = response.stream.listen(
          (chunk) {
            if (!result.isCompleted) bytes.add(chunk);
          },
          onError: (Object error, StackTrace stack) => fail(error, stack),
          onDone: () {
            if (result.isCompleted) return;
            result.complete(
              http.StreamedResponse(
                http.ByteStream.fromBytes(bytes.takeBytes()),
                response.statusCode,
                contentLength: response.contentLength,
                request: response.request ?? request,
                headers: response.headers,
                isRedirect: response.isRedirect,
                persistentConnection: response.persistentConnection,
                reasonPhrase: response.reasonPhrase,
              ),
            );
            stop();
            body = null;
          },
          cancelOnError: true,
        );
      } catch (error, stack) {
        fail(error, stack);
      }
    }());
    return result.future;
  }

  @override
  void close() => _inner.close();
}
