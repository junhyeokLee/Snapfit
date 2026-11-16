final _shortKoreanWords = RegExp(r'[가-힣]+');

/// Display-only wrapping for short Korean words. Keep the original string as
/// the spoken label; long words retain native character wrapping.
String keepShortKoreanWords(String text) =>
    text.replaceAllMapped(_shortKoreanWords, (match) {
      final word = match[0]!;
      return word.length > 1 && word.length <= 5
          ? word.split('').join('\u2060')
          : word;
    });
