import 'dart:convert';

import 'package:flutter_gemini/flutter_gemini.dart';

/// Service for AI-powered translations using Google Gemini.
class AiTranslationService {
  static bool _initialized = false;

  /// Initialize Gemini with the API key. Call once at app startup.
  static void initialize() {
    if (_initialized) return;
    Gemini.init(apiKey: 'INTER_YOUR_API_KEY');
    _initialized = true;
  }

  /// Language name mapping with dialect-aware descriptions for the AI prompt.
  static String _languageDescription(String langCode) {
    switch (langCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'Arabic (العربية)';
      case 'ku':
        return 'Kurdish Kurmanji / Bahdini dialect (کوردیا بەهدینی) — written in Arabic script. Example: "My name is Azad, I am 37 years old" → "ناڤێ من ئازادە، ژیێ من ٣٧ سالە"';
      case 'ks':
        return 'Kurdish Sorani dialect (کوردیا سۆرانی) — written in Arabic script. Example: "My name is Azad, I am 37 years old" → "ناوم ئازادە، تەمەنم ٣٧ ساڵە"';
      case 'fa':
        return 'Persian / Farsi (فارسی)';
      case 'he':
        return 'Hebrew (עברית)';
      case 'ur':
        return 'Urdu (اردو)';
      case 'tr':
        return 'Turkish (Türkçe)';
      case 'fr':
        return 'French (Français)';
      case 'de':
        return 'German (Deutsch)';
      case 'es':
        return 'Spanish (Español)';
      case 'it':
        return 'Italian (Italiano)';
      case 'pt':
        return 'Portuguese (Português)';
      case 'ja':
        return 'Japanese (日本語)';
      case 'ko':
        return 'Korean (한국어)';
      case 'zh':
        return 'Chinese Simplified (简体中文)';
      case 'ru':
        return 'Russian (Русский)';
      case 'hi':
        return 'Hindi (हिन्दी)';
      case 'nl':
        return 'Dutch (Nederlands)';
      case 'sv':
        return 'Swedish (Svenska)';
      case 'pl':
        return 'Polish (Polski)';
      default:
        return 'Language code "$langCode"';
    }
  }

  /// Generate a single translation for [targetLang] given a [key] and
  /// existing [referenceTranslations] from other languages.
  static Future<String?> generateTranslation({
    required String key,
    required String targetLang,
    required Map<String, String?> referenceTranslations,
  }) async {
    initialize();

    // Build reference context from existing translations
    final refs = <String>[];
    for (final entry in referenceTranslations.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        refs.add('- ${_languageDescription(entry.key)}: "${entry.value}"');
      }
    }

    final targetDesc = _languageDescription(targetLang);

    String prompt;
    if (refs.isNotEmpty) {
      prompt = '''You are a professional app localization translator.

Given the following translation key and existing translations for a mobile/desktop app UI:

Key: "$key"
Existing translations:
${refs.join('\n')}

Translate this to $targetDesc.

IMPORTANT RULES:
- Return ONLY the translated text, nothing else. No quotes, no explanation.
- Keep it natural and appropriate for a UI context (buttons, labels, messages).
- Keep any placeholders like {name}, {count}, \$variable unchanged.
- For Kurdish Kurmanji (ku) and Kurdish Sorani (ks): these are DIFFERENT dialects with different vocabulary and grammar. Translate each independently and accurately for its specific dialect.
- Match the tone and formality of the existing translations.
''';
    } else {
      prompt = '''You are a professional app localization translator.

Given the following translation key for a mobile/desktop app UI:

Key: "$key"

Generate a natural UI translation for this key in $targetDesc.

IMPORTANT RULES:
- Return ONLY the translated text, nothing else. No quotes, no explanation.
- The key name hints at the UI context (e.g., "homeTitle" → title of home screen, "btnSave" → save button label).
- Keep any placeholders like {name}, {count}, \$variable unchanged.
- Keep it concise and appropriate for UI display.
''';
    }

    try {
      final gemini = Gemini.instance;
      final response = await gemini.prompt(parts: [Part.text(prompt)]);
      final text = response?.output?.trim();
      if (text == null || text.isEmpty) return null;
      // Remove quotes if the AI wrapped the response
      return _cleanResponse(text);
    } catch (e) {
      return null;
    }
  }

  /// Generate translations for ALL languages for a given key.
  /// Returns a map of langCode -> translation.
  static Future<Map<String, String>> generateAllTranslations({
    required String key,
    required List<String> languages,
    required Map<String, String?> existingTranslations,
  }) async {
    initialize();

    final results = <String, String>{};

    // Find which languages need translation
    final needsTranslation = <String>[];
    for (final lang in languages) {
      final existing = existingTranslations[lang];
      if (existing == null || existing.isEmpty) {
        needsTranslation.add(lang);
      }
    }

    if (needsTranslation.isEmpty) return results;

    // Build reference context
    final refs = <String>[];
    for (final entry in existingTranslations.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        refs.add('- ${_languageDescription(entry.key)}: "${entry.value}"');
      }
    }

    // Build target language list
    final targetDescs = needsTranslation
        .map((l) => '- $l: ${_languageDescription(l)}')
        .join('\n');

    String prompt;
    if (refs.isNotEmpty) {
      prompt = '''You are a professional app localization translator.

Given the following translation key and existing translations for a mobile/desktop app UI:

Key: "$key"
Existing translations:
${refs.join('\n')}

Translate this to ALL of the following languages:
$targetDescs

IMPORTANT RULES:
- Return ONLY a JSON object with language codes as keys and translations as values.
- Example format: {"fr": "Bonjour", "de": "Hallo"}
- No markdown, no explanation, no code blocks — just the raw JSON object.
- Keep it natural and appropriate for a UI context.
- Keep any placeholders like {name}, {count}, \$variable unchanged.
- For Kurdish Kurmanji (ku) and Kurdish Sorani (ks): these are DIFFERENT dialects with different vocabulary and grammar. Translate each independently and accurately.
''';
    } else {
      prompt = '''You are a professional app localization translator.

Given the following translation key for a mobile/desktop app UI:

Key: "$key"

Generate natural UI translations for ALL of the following languages:
$targetDescs

IMPORTANT RULES:
- Return ONLY a JSON object with language codes as keys and translations as values.
- Example format: {"fr": "Bonjour", "de": "Hallo"}
- No markdown, no explanation, no code blocks — just the raw JSON object.
- The key name hints at the UI context (e.g., "homeTitle" → home screen title).
- Keep any placeholders like {name}, {count}, \$variable unchanged.
- For Kurdish Kurmanji (ku) and Kurdish Sorani (ks): these are DIFFERENT dialects. Translate each independently.
''';
    }

    try {
      final gemini = Gemini.instance;
      final response = await gemini.prompt(parts: [Part.text(prompt)]);
      final text = response?.output?.trim();
      if (text == null || text.isEmpty) return results;

      // Parse the JSON response
      final parsed = _parseJsonResponse(text);
      if (parsed != null) {
        for (final lang in needsTranslation) {
          if (parsed.containsKey(lang)) {
            results[lang] = parsed[lang]!;
          }
        }
      }
    } catch (_) {
      // If batch fails, fall back to individual translations
      for (final lang in needsTranslation) {
        final translation = await generateTranslation(
          key: key,
          targetLang: lang,
          referenceTranslations: {
            ...existingTranslations,
            ...results, // include already-generated ones as reference
          },
        );
        if (translation != null) {
          results[lang] = translation;
        }
      }
    }

    return results;
  }

  /// Clean AI response — remove surrounding quotes, markdown artifacts.
  static String _cleanResponse(String text) {
    var cleaned = text;
    // Remove markdown code block wrappers
    if (cleaned.startsWith('```') && cleaned.endsWith('```')) {
      cleaned = cleaned.substring(3, cleaned.length - 3).trim();
      if (cleaned.startsWith('json')) {
        cleaned = cleaned.substring(4).trim();
      }
    }
    // Remove surrounding quotes
    if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
        (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    return cleaned.trim();
  }

  /// Parse a JSON response from the AI, handling markdown wrapping.
  static Map<String, String>? _parseJsonResponse(String text) {
    var cleaned = text;
    // Remove markdown code block wrappers
    if (cleaned.contains('```')) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }
    }
    try {
      final Map<String, dynamic> json = _jsonDecode(cleaned);
      return json.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      // Try to extract JSON object from the text
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        try {
          final Map<String, dynamic> json =
              _jsonDecode(cleaned.substring(start, end + 1));
          return json.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  static Map<String, dynamic> _jsonDecode(String source) {
    return Map<String, dynamic>.from(
      jsonDecode(source) as Map,
    );
  }
}
