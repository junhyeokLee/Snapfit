import 'ai_contract_generator.dart';

Future<void> main(List<String> args) => generateAiContract(
  args: args,
  sourcePath: 'supabase/functions/ai-album-draft/composition-contract.json',
  targetPath:
      'lib/features/album/ai_album/domain/ai_template_composition.g.dart',
  constantName: 'aiTemplateCompositionContract',
  generatorPath: 'tool/generate_ai_composition.dart',
);
