import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

class _ProbedTemplate extends PremiumTemplate {
  _ProbedTemplate(int id, this.onRead, {required String Function() document})
    : super(
        id: id,
        title: 'Metadata $id',
        coverImageUrl: '',
        previewImages: const [],
        pageCount: 12,
        userCount: 0,
        documentBuilder: document,
      );

  final void Function() onRead;
  @override
  int get id {
    onRead();
    return super.id;
  }
}

void main() {
  for (final count in [64, 256]) {
    test(
      'merging $count local templates without server rows performs bounded metadata work',
      () {
        var reads = 0;
        var documentBuilds = 0;
        final source = [
          for (var i = 0; i < count; i++)
            _ProbedTemplate(
              700000 + i,
              () => reads++,
              document: () {
                documentBuilds++;
                throw StateError('Merging metadata must not author documents');
              },
            ),
        ];
        final result = mergeTemplatesWithServer(source, []);
        final mergeReads = reads;
        debugPrint(
          'store merge metadata reads: count=$count reads=$mergeReads',
        );
        expect(result, orderedEquals(source));
        expect(documentBuilds, 0);
        expect(
          mergeReads,
          lessThanOrEqualTo(count * 12),
          reason: 'Appending local templates must not rescan all prior rows',
        );
      },
    );
  }

  test(
    'membership indexing preserves server order, overlays and duplicate handling',
    () {
      PremiumTemplate local(int id) => PremiumTemplate(
        id: id,
        title: 'Local $id',
        coverImageUrl: '',
        previewImages: const [],
        pageCount: 12,
        userCount: 0,
        isPremium: true,
        documentBuilder: () => throw StateError('Documents stay lazy'),
      );
      final first = local(700001);
      final second = local(700002);
      final other = local(800001).copyWith(isPremium: false);
      final serverSecond = second.copyWith(
        title: 'Stale title',
        isPremium: false,
        isLiked: true,
        likeCount: 17,
      );
      final result = mergeTemplatesWithServer(
        [first, second, first],
        [serverSecond, other, serverSecond],
      );
      expect(result.map((t) => t.id), [700002, 800001, 700002, 700001]);
      expect(result.first.title, second.title);
      expect(result.first.isPremium, isTrue);
      expect(result.first.likeCount, 17);
      expect(result.first.isLiked, isTrue);
      expect(result.first.documentBuilder, same(second.documentBuilder));
      expect(result[1], same(other));
      expect(result.last, same(first));
    },
  );
}
