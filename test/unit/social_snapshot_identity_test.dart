import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_snapshot_identity.dart';

void main() {
  test(
    'gateway token renewal keeps artwork identity while preserving resource selectors',
    () {
      const base =
          'https://project.supabase.co/functions/v1/social-media?work=one&position=0';
      expect(
        socialSnapshotIdentity('$base&token=old'),
        socialSnapshotIdentity('$base&token=new'),
      );
      expect(
        socialSnapshotIdentity('$base&token=new'),
        isNot(
          socialSnapshotIdentity(
            '${base.replaceFirst('position=0', 'position=1')}&token=new',
          ),
        ),
      );
      expect(
        socialSnapshotIdentity('$base&token=new'),
        isNot(
          socialSnapshotIdentity(
            '${base.replaceFirst('work=one', 'work=two')}&token=new',
          ),
        ),
      );
    },
  );
  test('storage renewal preserves render transforms and host boundaries', () {
    const base =
        'https://project.supabase.co/storage/v1/render/image/sign/social-snapshots/owner/work/0.png?width=800';
    expect(
      socialSnapshotIdentity('$base&token=old'),
      socialSnapshotIdentity('$base&token=new'),
    );
    expect(
      socialSnapshotIdentity('$base&token=new'),
      isNot(
        socialSnapshotIdentity(
          '${base.replaceFirst('width=800', 'width=600')}&token=new',
        ),
      ),
    );
    expect(
      socialSnapshotIdentity('$base&token=new'),
      isNot(
        socialSnapshotIdentity(
          '${base.replaceFirst('project.supabase.co', 'another.supabase.co')}&token=new',
        ),
      ),
    );
  });
  test('unrelated URLs keep token and every other identity-bearing value', () {
    const first = 'https://example.com/photos/one.png?token=one';
    const second = 'https://example.com/photos/one.png?token=two';
    expect(socialSnapshotIdentity(first), first);
    expect(socialSnapshotIdentity(second), second);
    expect(
      socialSnapshotIdentity('asset://preview.png'),
      'asset://preview.png',
    );
  });
}
