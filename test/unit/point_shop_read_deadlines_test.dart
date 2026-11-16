import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';

class _Repository extends Mock implements PointShopRepository {}

const _product = PointShopProduct(
  productKey: 'template:test',
  kind: 'template',
  assetId: 'test',
  title: '검증 디자인',
  pointPrice: 1800,
  isActive: true,
);

void main() {
  test(
    'default container exposes one catalog deadline and rejects late prices after explicit retry',
    () {
      fakeAsync((clock) {
        final old = Completer<List<PointShopProduct>>();
        final fresh = Completer<List<PointShopProduct>>();
        final repository = _Repository();
        var reads = 0;
        when(
          () => repository.loadCatalog(),
        ).thenAnswer((_) => ++reads == 1 ? old.future : fresh.future);
        final container = ProviderContainer(
          overrides: [
            pointShopRepositoryProvider.overrideWithValue(repository),
          ],
        );
        final subscription = container.listen(
          pointShopCatalogProvider,
          (_, __) {},
        );
        Object? failure;
        unawaited(
          container
              .read(pointShopCatalogProvider.future)
              .then<void>(
                (_) {},
                onError: (Object error) {
                  failure = error;
                },
              ),
        );
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 12));
        clock.flushMicrotasks();
        expect(failure, isA<TimeoutException>());
        expect(container.read(pointShopCatalogProvider).hasError, isTrue);
        expect(container.read(pointShopCatalogProvider).isLoading, isFalse);
        expect(container.read(pointShopCatalogProvider).retrying, isFalse);
        // A production container must not hide this error in a 200ms rebuild.
        clock.elapse(const Duration(milliseconds: 300));
        clock.flushMicrotasks();
        expect(reads, 1);
        expect(container.read(pointShopCatalogProvider).isLoading, isFalse);
        container.invalidate(pointShopCatalogProvider);
        unawaited(container.read(pointShopCatalogProvider.future));
        clock.flushMicrotasks();
        expect(reads, 2);
        fresh.complete([_product]);
        clock.flushMicrotasks();
        expect(
          container
              .read(pointShopCatalogProvider)
              .requireValue
              .single
              .pointPrice,
          1800,
        );
        old.complete([
          const PointShopProduct(
            productKey: 'template:test',
            kind: 'template',
            assetId: 'test',
            title: '늦은 무료 가격',
            pointPrice: 0,
            isActive: true,
          ),
        ]);
        clock.flushMicrotasks();
        expect(
          container
              .read(pointShopCatalogProvider)
              .requireValue
              .single
              .pointPrice,
          1800,
        );
        subscription.close();
        container.dispose();
        clock.flushMicrotasks();
      });
    },
  );

  test(
    'stalled ownership fails closed and retries without retaining the old grant',
    () {
      fakeAsync((clock) {
        final old = Completer<Set<String>>();
        final fresh = Completer<Set<String>>();
        final repository = _Repository();
        var reads = 0;
        when(() => repository.currentUserId).thenReturn('owner-a');
        when(
          () => repository.authChanges,
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => repository.loadOwnedKeys(),
        ).thenAnswer((_) => ++reads == 1 ? old.future : fresh.future);
        final container = ProviderContainer(
          retry: (_, __) => null,
          overrides: [
            pointShopRepositoryProvider.overrideWithValue(repository),
            visibleOrderOwnerProvider.overrideWithValue('owner-a'),
          ],
        );
        unawaited(container.read(pointShopSessionProvider.future));
        clock.flushMicrotasks();
        final subscription = container.listen(
          ownedPointShopKeysProvider,
          (_, __) {},
        );
        Object? failure;
        unawaited(
          container
              .read(ownedPointShopKeysProvider.future)
              .then<void>(
                (_) {},
                onError: (Object error) {
                  failure = error;
                },
              ),
        );
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 12));
        clock.flushMicrotasks();
        expect(failure, isA<TimeoutException>());
        expect(container.read(ownedPointShopKeysProvider).hasError, isTrue);
        container.invalidate(ownedPointShopKeysProvider);
        unawaited(container.read(ownedPointShopKeysProvider.future));
        clock.flushMicrotasks();
        fresh.complete(<String>{});
        clock.flushMicrotasks();
        expect(
          container.read(ownedPointShopKeysProvider).requireValue,
          isEmpty,
        );
        old.complete({'template:test'});
        clock.flushMicrotasks();
        expect(
          container.read(ownedPointShopKeysProvider).requireValue,
          isEmpty,
        );
        subscription.close();
        container.dispose();
        clock.flushMicrotasks();
      });
    },
  );
}
