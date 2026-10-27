import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/photo_failure_versions.dart';

void main() {
  test(
    'decoded recovery tokens reuse failure slots and cannot revive a newer rejection',
    () {
      final failures = PhotoFailureVersions();
      final original = failures.version;
      failures.reject('scope', 'url', original);
      final first = failures.version;
      failures.recover('scope', 'url', original);
      expect(failures.recoveryVersion('scope', 'url'), isNull);
      failures.recover('scope', 'url', first);
      expect(failures.recoveryVersion('scope', 'url'), first);
      expect(failures.rejectedSince('scope', 'url', original), isTrue);
      // An old observer must not erase this successful retry.
      failures.reject('scope', 'url', original);
      expect(failures.recoveryVersion('scope', 'url'), first);
      // A genuinely newer failure must supersede it.
      failures.reject('scope', 'url', first);
      expect(failures.recoveryVersion('scope', 'url'), isNull);
      failures.recover('scope', 'url', first);
      expect(failures.recoveryVersion('scope', 'url'), isNull);
      failures.clear();
      expect(failures.recoveryVersion('scope', 'url'), isNull);
    },
  );

  test(
    'success alone creates no entries and recovery does not extend the failure lifetime',
    () {
      var now = DateTime.utc(2026, 10, 25);
      final failures = PhotoFailureVersions(capacity: 1, now: () => now);
      failures.reject('scope', 'failed', failures.version);
      final version = failures.version;
      failures.recover('scope', 'healthy', version);
      expect(failures.rejectionVersion('scope', 'failed'), version);
      now = now.add(const Duration(seconds: 29));
      failures.recover('scope', 'failed', version);
      expect(failures.recoveryVersion('other', 'failed'), isNull);
      expect(failures.recoveryVersion('scope', 'failed'), version);
      now = now.add(const Duration(seconds: 2));
      expect(failures.recoveryVersion('scope', 'failed'), isNull);
    },
  );

  test(
    'concurrent consumers share rejection but a new load may reconsider it',
    () {
      final failures = PhotoFailureVersions();
      final load = failures.version;
      failures.reject('photo', 'old', load);
      final rejected = failures.version;
      expect(failures.rejectedSince('photo', 'old', load), isTrue);
      failures.reject('photo', 'old', load);
      expect(failures.version, rejected);
      expect(failures.rejectedSince('photo', 'old', rejected), isFalse);
      failures.reject('photo', 'old', rejected);
      expect(failures.version, greaterThan(rejected));
      final newer = failures.version;
      failures.reject('photo', 'old', load);
      expect(failures.version, newer);
    },
  );

  test('failure identity includes cache/decode scope and resolved URL', () {
    final failures = PhotoFailureVersions();
    final load = failures.version;
    failures.reject('photo', 'old', load);
    expect(failures.rejectedSince('photo', 'fresh', load), isFalse);
    expect(failures.rejectedSince('other', 'old', load), isFalse);
  });

  test(
    'logical aliases share failure metadata without crossing cache or decode scopes',
    () {
      final failures = PhotoFailureVersions();
      const urlScope = (1, 128, 128, null, null);
      const storageScope = (1, 128, 128, null, null);
      const otherCache = (2, 128, 128, null, null);
      const otherDecode = (1, 256, 256, null, null);
      const otherDiskDecode = (1, 128, 128, 256, 256);
      final load = failures.version;
      failures.reject(urlScope, 'resolved-url', load);
      final version = failures.rejectionVersion(urlScope, 'resolved-url');
      expect(
        failures.rejectedSince(storageScope, 'resolved-url', load),
        isTrue,
      );
      expect(failures.reject(storageScope, 'resolved-url', load), isFalse);
      expect(failures.rejectionVersion(storageScope, 'resolved-url'), version);
      for (final scope in [otherCache, otherDecode, otherDiskDecode]) {
        expect(failures.rejectedSince(scope, 'resolved-url', load), isFalse);
      }
    },
  );

  test('entries have a fixed lifetime and a bounded count', () {
    var now = DateTime.utc(2026, 10, 25);
    final failures = PhotoFailureVersions(capacity: 2, now: () => now);
    final load = failures.version;
    failures.reject('a', 'url', load);
    failures.reject('b', 'url', load);
    failures.reject('c', 'url', load);
    expect(failures.rejectedSince('a', 'url', load), isFalse);
    expect(failures.rejectedSince('b', 'url', load), isTrue);
    now = now.add(const Duration(seconds: 31));
    expect(failures.rejectedSince('b', 'url', load), isFalse);
    expect(failures.rejectedSince('c', 'url', load), isFalse);
  });

  test('pressure cleanup never reuses an older load version', () {
    final failures = PhotoFailureVersions();
    final before = failures.version;
    failures.reject('a', 'url', before);
    failures.clear();
    final after = failures.version;
    expect(after, greaterThan(before));
    expect(failures.rejectedSince('a', 'url', before), isFalse);
    failures.reject('a', 'url', after);
    expect(failures.rejectedSince('a', 'url', before), isTrue);
  });
}
