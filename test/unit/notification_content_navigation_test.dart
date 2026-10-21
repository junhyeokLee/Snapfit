import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/notification_content_navigation.dart';

void main() {
  const album = NotificationContentTarget(NotificationContentKind.album, 7);
  const template = NotificationContentTarget(
    NotificationContentKind.template,
    12,
  );
  final now = DateTime.utc(2026, 10, 19);

  test(
    'native external links and push payloads normalize to the same target',
    () {
      for (final entry in {
        'snapfit://album?albumId=7': album,
        'snapfit://template?templateId=12': template,
      }.entries) {
        expect(
          NotificationContentTarget.fromUri(Uri.parse(entry.key)),
          entry.value,
        );
        expect(
          NotificationContentTarget.fromPayload({'deeplink': entry.key}),
          entry.value,
        );
      }
      expect(NotificationContentTarget.fromPayload({'albumId': '7'}), album);
      expect(
        NotificationContentTarget.fromPayload({'templateId': 12}),
        template,
      );
    },
  );

  test(
    'native content links reject unsupported schemes hosts paths and ambiguous identifiers',
    () {
      for (final link in [
        'https://album?albumId=7',
        'javascript://album?albumId=7',
        'snapfit://other?albumId=7',
        'snapfit://album/delete?albumId=7',
        'snapfit://user@album?albumId=7',
        'snapfit://album:12?albumId=7',
        'snapfit://album?albumId=7#private',
        'snapfit://album?albumId=7&albumId=8',
        'snapfit://album?albumId=0',
        'snapfit://album?albumId=-1',
        'snapfit://album?albumId=1.5',
        'snapfit://album?albumId=%207',
        'snapfit://template?templateId=9007199254740992',
        'snapfit://template',
      ]) {
        expect(
          NotificationContentTarget.fromUri(Uri.parse(link)),
          isNull,
          reason: link,
        );
        expect(
          NotificationContentTarget.fromPayload({'deeplink': link}),
          isNull,
          reason: link,
        );
      }
    },
  );

  test(
    'payload IDs must be positive safe integers and invalid explicit IDs cannot fall through',
    () {
      for (final invalid in [
        0,
        -1,
        1.5,
        true,
        '7/delete',
        ' 7',
        '9007199254740992',
      ]) {
        expect(
          NotificationContentTarget.fromPayload({
            'albumId': invalid,
            'deeplink': 'snapfit://album?albumId=7',
          }),
          isNull,
        );
      }
      expect(
        NotificationContentTarget.positiveId('9007199254740991'),
        9007199254740991,
      );
    },
  );

  NotificationContentOpen? take(
    NotificationContentNavigation navigation, {
    String? owner = 'owner',
    String? profile = 'owner',
    bool ready = true,
    DateTime? at,
  }) => navigation.take(
    ownerId: owner,
    profileOwnerId: profile,
    navigatorReady: ready,
    now: at ?? now,
  );

  test(
    'cold start waits for both a stable root and the matching validated profile',
    () {
      final navigation = NotificationContentNavigation()
        ..observeOwner('owner')
        ..receive(album, ownerId: 'owner');
      expect(take(navigation, ready: false), isNull);
      expect(take(navigation, profile: null), isNull);
      expect(take(navigation, profile: 'cached-other-owner'), isNull);
      expect(navigation.hasPending, true);
      expect(take(navigation)!.target, album);
      expect(navigation.hasPending, false);
    },
  );

  test(
    'a logged out external link waits for login and a targeted tap rejects another account',
    () {
      final external = NotificationContentNavigation()..receive(template);
      expect(take(external, owner: null, profile: null), isNull);
      external.observeOwner('owner');
      expect(take(external)!.target, template);
      final targeted = NotificationContentNavigation()
        ..receive(album, ownerId: 'owner');
      targeted.observeOwner('other');
      expect(take(targeted, owner: 'other', profile: 'other'), isNull);
      expect(targeted.hasPending, false);
    },
  );

  test(
    'foreground and background delivery duplicates cannot invalidate an in-flight open',
    () {
      final navigation = NotificationContentNavigation()
        ..observeOwner('owner')
        ..receive(album, ownerId: 'owner');
      final opening = take(navigation)!;
      navigation.receive(album, ownerId: 'owner');
      expect(
        navigation.isCurrent(
          opening,
          ownerId: 'owner',
          profileOwnerId: 'owner',
        ),
        true,
      );
      expect(take(navigation), isNull);
      navigation.finish(opening, opened: true, now: now);
      navigation.receive(album, ownerId: 'owner');
      expect(
        take(navigation, at: now.add(const Duration(milliseconds: 500))),
        isNull,
      );
      navigation.receive(album, ownerId: 'owner');
      expect(
        take(navigation, at: now.add(const Duration(seconds: 3)))!.target,
        album,
      );
    },
  );

  test(
    'a newer content target invalidates asynchronous repository and reader preparation work',
    () {
      final navigation = NotificationContentNavigation()
        ..observeOwner('owner')
        ..receive(album, ownerId: 'owner');
      final opening = take(navigation)!;
      navigation.receive(template, ownerId: 'owner');
      expect(
        navigation.isCurrent(
          opening,
          ownerId: 'owner',
          profileOwnerId: 'owner',
        ),
        false,
      );
      navigation.finish(opening, opened: true, now: now);
      final latest = take(navigation)!;
      expect(latest.target, template);
      expect(
        navigation.isCurrent(latest, ownerId: 'owner', profileOwnerId: 'owner'),
        true,
      );
    },
  );

  test(
    'logout direct account switch and profile mismatch invalidate pending work',
    () {
      for (final nextOwner in <String?>[null, 'other']) {
        final navigation = NotificationContentNavigation()
          ..observeOwner('owner')
          ..receive(album, ownerId: 'owner');
        final opening = take(navigation)!;
        expect(
          navigation.isCurrent(
            opening,
            ownerId: 'owner',
            profileOwnerId: 'other',
          ),
          false,
        );
        navigation.receive(template, ownerId: 'owner');
        navigation.observeOwner(nextOwner);
        expect(
          navigation.isCurrent(
            opening,
            ownerId: nextOwner,
            profileOwnerId: nextOwner,
          ),
          false,
        );
        expect(navigation.hasPending, false);
      }
    },
  );

  test(
    'a failed open may be retried immediately and a cancelled open cannot finish a newer request',
    () {
      final navigation = NotificationContentNavigation()
        ..observeOwner('owner')
        ..receive(album, ownerId: 'owner');
      final failed = take(navigation)!;
      navigation.finish(failed, opened: false, now: now);
      navigation.receive(album, ownerId: 'owner');
      final retry = take(navigation)!;
      navigation.cancel();
      navigation.receive(template, ownerId: 'owner');
      final latest = take(navigation)!;
      navigation.finish(retry, opened: true, now: now);
      expect(
        navigation.isCurrent(latest, ownerId: 'owner', profileOwnerId: 'owner'),
        true,
      );
    },
  );

  test(
    'new targets and account changes release blocked asynchronous opens',
    () async {
      for (final accountChange in [false, true]) {
        final navigation = NotificationContentNavigation()
          ..observeOwner('owner')
          ..receive(album, ownerId: 'owner');
        final opening = take(navigation)!;
        var cancelled = false;
        final signal = opening.cancelled.then((_) => cancelled = true);
        if (accountChange) {
          navigation.observeOwner('other');
        } else {
          navigation.receive(template, ownerId: 'owner');
        }
        await signal;
        expect(cancelled, true);
      }
    },
  );
}
