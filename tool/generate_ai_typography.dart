import 'ai_contract_generator.dart';

// One contract drives server validation and the synchronous Flutter parser.
Future<void> main(List<String> args) => generateAiContract(
  args: args,
  sourcePath: 'supabase/functions/ai-album-draft/typography-contract.json',
  targetPath:
      'lib/features/album/ai_album/domain/ai_template_typography.g.dart',
  constantName: 'aiTemplateTypographyContract',
  generatorPath: 'tool/generate_ai_typography.dart',
);
