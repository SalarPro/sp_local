import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../models/i18n_models.dart';

/// Service for loading and saving i18n JSON files.
/// All I/O is async and JSON parsing/encoding runs in isolates
/// to avoid blocking the UI thread on large files.
class I18nService {
  static final RegExp _langReg =
      RegExp(r'^strings(_([a-zA-Z]+))?\.i18n\.json$');

  /// Known RTL language codes.
  static const rtlLangs = {'ar', 'fa', 'he', 'ku', 'ks', 'ur'};

  /// Whether a language code is RTL.
  static bool isRtl(String langCode) => rtlLangs.contains(langCode);

  /// Dart reserved keywords and built-in identifiers that cannot be used as keys.
  static const _dartKeywords = <String>{
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
    'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
    'external', 'factory', 'false', 'final', 'finally', 'for', 'Function',
    'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
    'late', 'library', 'mixin', 'new', 'null', 'of', 'on', 'operator', 'part',
    'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
    'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'typedef',
    'var', 'void', 'when', 'while', 'with', 'yield',
    // Common built-in types
    'int', 'double', 'String', 'bool', 'List', 'Map', 'Set', 'num', 'Object',
    'Null', 'Never', 'Future', 'Stream', 'Iterable', 'Type', 'Symbol',
  };

  /// Whether [key] is a Dart reserved keyword or built-in identifier.
  static bool isDartKeyword(String key) => _dartKeywords.contains(key);

  /// Validates a key string: must start with lowercase a-z, followed by
  /// letters, digits, or underscores only. Must not be a Dart keyword.
  static bool isValidKey(String key) {
    if (key.isEmpty) return false;
    if (!RegExp(r'^[a-z][a-zA-Z0-9_]*$').hasMatch(key)) return false;
    if (isDartKeyword(key)) return false;
    return true;
  }

  /// Returns a human-readable validation error for [key], or null if valid.
  static String? validateKey(String key) {
    if (key.isEmpty) return 'Key cannot be empty';
    if (!RegExp(r'^[a-z]').hasMatch(key)) {
      return 'Must start with a lowercase letter (a-z)';
    }
    if (!RegExp(r'^[a-zA-Z0-9_ .\-]+$').hasMatch(key)) {
      return 'Contains invalid characters';
    }
    final camel = toCamelCase(key);
    if (isDartKeyword(camel)) return '"$camel" is a Dart reserved keyword';
    return null;
  }

  /// Converts any string to camelCase.
  /// Splits on spaces, hyphens, underscores, dots, and existing case boundaries,
  /// then joins as camelCase.
  static String toCamelCase(String input) {
    if (input.isEmpty) return input;

    // Split on non-alphanumeric characters and camelCase boundaries
    final words = input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => ' ${m.group(0)}',
        )
        .split(RegExp(r'[\s_\-\.]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return input;

    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      final word = words[i].toLowerCase();
      if (i == 0) {
        buffer.write(word);
      } else {
        buffer.write(word[0].toUpperCase());
        if (word.length > 1) buffer.write(word.substring(1));
      }
    }

    final result = buffer.toString();
    // Strip any leading non-letter characters
    final cleaned = result.replaceFirst(RegExp(r'^[^a-zA-Z]+'), '');
    if (cleaned.isEmpty) return result;
    // Ensure first char is lowercase
    return cleaned[0].toLowerCase() + cleaned.substring(1);
  }

  /// Loads all i18n JSON files in the given folder and returns an [I18nProject].
  /// JSON parsing happens in an isolate to avoid UI jank on large files.
  static Future<I18nProject> loadI18nFolder(String folderPath) async {
    final dir = Directory(folderPath);
    final entities = await dir.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) =>
            p.basename(f.path).endsWith('.json') &&
            p.basename(f.path).startsWith('strings'))
        .toList();

    // Read all file contents in parallel (async, not blocking UI)
    final Map<String, String> fileContents = {};
    final Map<String, String> fileToLang = {};

    for (final file in files) {
      final name = p.basename(file.path);
      final match = _langReg.firstMatch(name);
      if (match == null) continue;

      String lang = 'en';
      if (match.group(2) != null) {
        lang = match.group(2)!.toLowerCase();
      }
      fileToLang[file.path] = lang;
      fileContents[file.path] = await file.readAsString();
    }

    // Parse JSON in an isolate to keep UI responsive for large files
    final result = await Isolate.run(() {
      return _parseJsonFiles(fileContents, fileToLang);
    });

    return I18nProject(
      folderPath: folderPath,
      languages: result.languages,
      entries: result.entries,
    );
  }

  /// Pure function that runs in an isolate — parses all JSON file contents
  /// and builds the entry list.
  static _ParseResult _parseJsonFiles(
    Map<String, String> fileContents,
    Map<String, String> fileToLang,
  ) {
    final Map<String, Map<String, String>> langToMap = {};
    final Set<String> allKeys = {};
    final List<String> languageCodes = [];

    for (final entry in fileContents.entries) {
      final lang = fileToLang[entry.key]!;
      languageCodes.add(lang);
      final map = json.decode(entry.value) as Map<String, dynamic>;
      langToMap[lang] = map.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      allKeys.addAll(map.keys);
    }

    // Order: en first, then alphabetical
    final codes = <String>{};
    final otherLangs = languageCodes.where((c) => c != 'en').toList()..sort();
    final orderedLangs = [
      if (languageCodes.contains('en')) 'en',
      ...otherLangs,
    ].where((c) => codes.add(c)).toList();

    // Build entries sorted by key
    final entries = allKeys.map((key) {
      final translations = <String, String?>{};
      for (final lang in orderedLangs) {
        translations[lang] = langToMap[lang]?[key];
      }
      return I18nEntry(key: key, translations: translations);
    }).toList();
    entries.sort((a, b) => a.key.compareTo(b.key));

    return _ParseResult(languages: orderedLangs, entries: entries);
  }

  /// Saves the project back to JSON files in the folder.
  /// JSON encoding runs in an isolate for large datasets.
  static Future<void> saveI18nFolder(I18nProject project) async {
    // Encode in isolate
    final encodedFiles = await Isolate.run(() {
      return _encodeJsonFiles(project);
    });

    // Write files (async I/O)
    for (final entry in encodedFiles.entries) {
      final file = File(p.join(project.folderPath, entry.key));
      await file.writeAsString(entry.value);
    }
  }

  /// Pure function that runs in an isolate — encodes entries to JSON strings
  /// per language file.
  static Map<String, String> _encodeJsonFiles(I18nProject project) {
    final Map<String, String> result = {};

    for (final lang in project.languages) {
      final Map<String, dynamic> langMap = {};
      for (final entry in project.entries) {
        final value = entry.translations[lang];
        // Always write the key even if value is null/empty — preserves key
        // presence across all language files for consistency
        langMap[entry.key] = value ?? '';
      }

      // Sort keys for consistent file output
      final sortedMap = Map.fromEntries(
        langMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );

      final filename = lang == 'en'
          ? 'strings.i18n.json'
          : 'strings_${lang.toLowerCase()}.i18n.json';

      result[filename] = const JsonEncoder.withIndent('  ').convert(sortedMap);
    }

    return result;
  }

  /// Creates a new language file with all existing keys set to empty string.
  static Future<void> addLanguageFile(
    String folderPath,
    String langCode,
    List<I18nEntry> existingEntries,
  ) async {
    final filename = 'strings_${langCode.toLowerCase()}.i18n.json';
    final file = File(p.join(folderPath, filename));

    final Map<String, dynamic> langMap = {};
    for (final entry in existingEntries) {
      langMap[entry.key] = '';
    }

    final sortedMap = Map.fromEntries(
      langMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final content = const JsonEncoder.withIndent('  ').convert(sortedMap);
    await file.writeAsString(content);
  }

  /// Deletes a language file from disk.
  static Future<void> removeLanguageFile(
    String folderPath,
    String langCode,
  ) async {
    final filename = langCode == 'en'
        ? 'strings.i18n.json'
        : 'strings_${langCode.toLowerCase()}.i18n.json';
    final file = File(p.join(folderPath, filename));
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Internal result class for isolate communication.
class _ParseResult {
  final List<String> languages;
  final List<I18nEntry> entries;

  _ParseResult({required this.languages, required this.entries});
}
