import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/auth/presentation/providers/public_template_return_intent.dart';

void main() {
  test(
    'choice stores only its ID and resolves the canonical template once',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final intent = container.read(
        publicTemplateReturnIntentProvider.notifier,
      );
      final selected = publishedCreationTemplates.first;
      expect(intent.remember(selected.id), isTrue);
      expect(container.read(publicTemplateReturnIntentProvider), selected.id);
      expect(identical(intent.consume(), selected), isTrue);
      expect(container.read(publicTemplateReturnIntentProvider), isNull);
      expect(intent.consume(), isNull);
    },
  );

  test(
    'unknown IDs clear an older choice and cannot restore arbitrary data',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final intent = container.read(
        publicTemplateReturnIntentProvider.notifier,
      );
      intent.remember(publishedCreationTemplates.first.id);
      expect(intent.remember(9007199254740991), isFalse);
      expect(container.read(publicTemplateReturnIntentProvider), isNull);
      expect(intent.consume(), isNull);
    },
  );

  test(
    'a new session has no persisted choice and explicit clearing cancels',
    () {
      final first = ProviderContainer();
      final second = ProviderContainer();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final intent = first.read(publicTemplateReturnIntentProvider.notifier);
      intent.remember(publishedCreationTemplates.last.id);
      expect(second.read(publicTemplateReturnIntentProvider), isNull);
      intent.clear();
      expect(intent.consume(), isNull);
    },
  );
}
