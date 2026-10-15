import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Browser-only storage transport. Payload validation belongs to the draft store.
class BrowserDraftDatabase {
  static const _databaseName = 'snapfit_album_creation_drafts';
  static const _storeName = 'drafts';
  static const _version = 1;

  /// Reads and optionally replaces one owner's record in one transaction.
  ///
  /// [action] and its writes run synchronously in the get-success event while
  /// IndexedDB keeps the transaction active. Read/write transactions therefore
  /// serialize a linked-draft identity check and update across browser tabs.
  /// A result is returned only after the transaction commits successfully.
  Future<T> transaction<T>({
    required String owner,
    required bool write,
    required T Function(
      JSObject? current,
      void Function(JSObject value) put,
      void Function() remove,
    ) action,
  }) async {
    if (owner.trim().isEmpty) {
      throw ArgumentError.value(owner, 'owner', 'Draft owner is required');
    }
    final database = await _open();
    try {
      final transaction = database.transaction(
        _storeName.toJS,
        write ? 'readwrite' : 'readonly',
      );
      final completed = Completer<T>();
      Object? failure;
      StackTrace? failureStack;
      var insideAction = false;
      var actionRan = false;
      late T actionValue;

      void remember(Object error, [StackTrace? stack]) {
        failure ??= error;
        failureStack ??= stack;
      }

      void abort() {
        try {
          transaction.abort();
        } catch (_) {
          // An already aborted transaction still delivers its abort event.
        }
      }

      void failCompletion(Object error) {
        if (!completed.isCompleted) {
          completed.completeError(error, failureStack);
        }
      }

      transaction.oncomplete = ((web.Event _) {
        if (completed.isCompleted) return;
        if (failure != null) {
          failCompletion(failure!);
        } else if (!actionRan) {
          failCompletion(const BrowserDraftDatabaseException('action_missing'));
        } else {
          completed.complete(actionValue);
        }
      }).toJS;
      transaction.onabort = ((web.Event _) {
        failCompletion(failure ?? _failure('transaction_aborted', transaction.error));
      }).toJS;
      transaction.onerror = ((web.Event _) {
        remember(_failure('transaction_failed', transaction.error));
        abort();
      }).toJS;

      final store = transaction.objectStore(_storeName);
      void watchWrite(web.IDBRequest request) {
        request.onerror = ((web.Event _) {
          remember(_failure('write_failed', request.error));
          abort();
        }).toJS;
      }

      void requireWrite() {
        if (!insideAction) {
          throw const BrowserDraftDatabaseException('action_inactive');
        }
        if (!write) {
          throw const BrowserDraftDatabaseException('readonly');
        }
      }

      final request = store.get(owner.toJS);
      request.onerror = ((web.Event _) {
        remember(_failure('read_failed', request.error));
        abort();
      }).toJS;
      request.onsuccess = ((web.Event _) {
        if (completed.isCompleted || failure != null) return;
        insideAction = true;
        try {
          final raw = request.result;
          if (raw != null && !raw.isA<JSObject>()) {
            throw const BrowserDraftDatabaseException('invalid_record');
          }
          actionValue = action(
            raw as JSObject?,
            (value) {
              requireWrite();
              watchWrite(store.put(value, owner.toJS));
            },
            () {
              requireWrite();
              watchWrite(store.delete(owner.toJS));
            },
          );
          if (actionValue is Future) {
            throw const BrowserDraftDatabaseException('async_action');
          }
          actionRan = true;
        } catch (error, stack) {
          remember(error, stack);
          abort();
        } finally {
          insideAction = false;
        }
      }).toJS;

      return await completed.future;
    } finally {
      database.close();
    }
  }

  Future<web.IDBDatabase> _open() {
    final completed = Completer<web.IDBDatabase>();
    late final web.IDBOpenDBRequest request;
    try {
      request = web.window.indexedDB.open(_databaseName, _version);
    } catch (_) {
      throw const BrowserDraftDatabaseException('unavailable');
    }

    void fail(Object error, [StackTrace? stack]) {
      if (!completed.isCompleted) completed.completeError(error, stack);
    }

    void clearHandlers() {
      request.onsuccess = null;
      request.onerror = null;
      request.onblocked = null;
      request.onupgradeneeded = null;
    }

    void abortUpgrade() {
      try {
        request.transaction?.abort();
      } catch (_) {
        // A failed or completed upgrade cannot be aborted again.
      }
    }

    request.onblocked = ((web.Event _) {
      // Open requests cannot be canceled. Keep success/upgrade handlers so a
      // later unblocked request is aborted or its connection is closed.
      fail(const BrowserDraftDatabaseException('blocked'));
    }).toJS;
    request.onupgradeneeded = ((web.Event _) {
      if (completed.isCompleted) {
        abortUpgrade();
        return;
      }
      try {
        final database = request.result as web.IDBDatabase;
        if (!database.objectStoreNames.contains(_storeName)) {
          database.createObjectStore(_storeName);
        }
      } catch (_, stack) {
        abortUpgrade();
        fail(const BrowserDraftDatabaseException('upgrade_failed'), stack);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      final error = _failure('open_failed', request.error);
      clearHandlers();
      fail(error);
    }).toJS;
    request.onsuccess = ((web.Event _) {
      web.IDBDatabase? database;
      try {
        database = request.result as web.IDBDatabase;
        clearHandlers();
        if (completed.isCompleted) {
          database.close();
          return;
        }
        if (!database.objectStoreNames.contains(_storeName)) {
          database.close();
          fail(const BrowserDraftDatabaseException('schema_missing'));
          return;
        }
        final connection = database;
        connection.onversionchange = ((web.Event _) => connection.close()).toJS;
        completed.complete(connection);
      } catch (_, stack) {
        database?.close();
        clearHandlers();
        fail(const BrowserDraftDatabaseException('open_failed'), stack);
      }
    }).toJS;
    return completed.future;
  }

  static BrowserDraftDatabaseException _failure(String code, web.DOMException? error) =>
      BrowserDraftDatabaseException(code, browserName: error?.name);
}

class BrowserDraftDatabaseException implements Exception {
  const BrowserDraftDatabaseException(this.code, {this.browserName});
  final String code;
  final String? browserName;

  @override
  String toString() => 'BrowserDraftDatabaseException($code${browserName == null ? '' : ': $browserName'})';
}
