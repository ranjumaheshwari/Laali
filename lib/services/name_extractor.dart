import 'package:flutter/foundation.dart';

class NameExtractor {
  /// Enhanced name extraction that preserves English words
  String extractName(String text) {
    if (text.isEmpty) return '';

    final lowerText = text.toLowerCase();
    debugPrint('Name extraction - Original text: $text');

    // Common Kannada name patterns
    final kannadaNamePatterns = [
      'ನನ್ನ ಹೆಸರು',
      'ನಾನು',
      'ಹೆಸರು',
      'ನನ್ನ ಪೆಸರು',
      'ನಾನ್',
    ];

    // Common English name patterns
    final englishNamePatterns = [
      'my name is',
      'my name',
      'name is',
      'i am',
      'call me',
    ];

    String cleanedText = text;

    // Check for Kannada patterns first
    for (final pattern in kannadaNamePatterns) {
      if (lowerText.contains(pattern)) {
        final patternIndex = lowerText.indexOf(pattern);
        cleanedText = text.substring(patternIndex + pattern.length).trim();
        debugPrint('Name extraction - After Kannada pattern: $cleanedText');
        break;
      }
    }

    // Check for English patterns
    for (final pattern in englishNamePatterns) {
      if (lowerText.contains(pattern)) {
        final patternIndex = lowerText.indexOf(pattern);
        cleanedText = text.substring(patternIndex + pattern.length).trim();
        debugPrint('Name extraction - After English pattern: $cleanedText');
        break;
      }
    }

    // Remove common suffixes (both languages)
    final suffixes = ['ಅವರು', 'ಆಗಿದೆ', 'ಎಂದು', 'ಎನ್ನುತ್ತಾರೆ', 'ಎನ್ನುವರು', 'is', 'am', 'are'];
    for (final suffix in suffixes) {
      if (cleanedText.toLowerCase().endsWith(suffix.toLowerCase())) {
        cleanedText = cleanedText.substring(0, cleanedText.length - suffix.length).trim();
      }
    }

    debugPrint('Name extraction - Final extracted: $cleanedText');
    return cleanedText.isNotEmpty ? cleanedText : text;
  }

  /// Enhanced name extraction with context awareness
  String extractNameFromContext(String text, String context) {
    String name = extractName(text);

    // Additional context-based cleaning
    if (context == 'username') {
      // For username context, remove common verbs and adjectives
      final commonVerbs = ['ಹೇಳು', 'ಕೇಳು', 'ತಿಳಿಸು', 'ಕೊಡು', 'please', 'kindly'];
      for (final verb in commonVerbs) {
        if (name.toLowerCase().endsWith(verb.toLowerCase())) {
          name = name.substring(0, name.length - verb.length).trim();
        }
      }

      // Normalize common Unicode quotation marks to simple quotes
      const smartQuotes = ['\u201C', '\u201D', '\u2018', '\u2019', '\u201E', '\u201F'];
      for (final q in smartQuotes) {
        name = name.replaceAll(RegExp(q), '');
      }

      // Remove any remaining ASCII quotes
      name = name.replaceAll('"', '');
      name = name.replaceAll('\'', '');

      // Remove punctuation but preserve word characters, whitespace and Kannada range
      name = name.replaceAll(RegExp(r"[^\w\s\u0C80-\u0CFF]"), ' ').trim();

      // Collapse multiple spaces to one
      name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return name;
  }
}

final nameExtractor = NameExtractor();
