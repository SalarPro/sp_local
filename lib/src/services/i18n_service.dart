import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/i18n_models.dart';

class I18nService {
  /// Loads all i18n JSON files in the given folder and returns a table model.
  static Future<I18nTableModel> loadI18nFolder(String folderPath) async {
    final dir = Directory(folderPath);
    final files = dir
        .listSync()
        .where((f) =>
            f.path.endsWith('.json') &&
            p.basename(f.path).startsWith('strings'))
        .toList();
    // Detect language codes
    final Map<String, Map<String, String>> langToMap = {};
    final Set<String> allKeys = {};
    final RegExp langReg = RegExp(r'^strings(_([a-zA-Z]+))?\.i18n\.json');
    final List<String> languageCodes = [];
    for (final file in files) {
      final name = p.basename(file.path);
      final match = langReg.firstMatch(name);
      String lang = 'en';
      if (match != null && match.group(2) != null) {
        lang = match.group(2)!.toLowerCase();
      }
      languageCodes.add(lang);
      final map = json.decode(File(file.path).readAsStringSync())
          as Map<String, dynamic>;
      langToMap[lang] = map.map((k, v) => MapEntry(k, v.toString()));
      allKeys.addAll(map.keys);
    }
    // Remove duplicates, keep order: en, then others
    final codes = <String>{};
    final orderedLangs = [
      if (languageCodes.contains('en')) 'en',
      ...languageCodes.where((c) => c != 'en')
    ].where((c) => codes.add(c)).toList();
    // Build entries
    final entries = allKeys.map((key) {
      final translations = <String, String?>{};
      for (final lang in orderedLangs) {
        translations[lang] = langToMap[lang]?[key];
      }
      return I18nStringEntry(key: key, translations: translations);
    }).toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return I18nTableModel(languageCodes: orderedLangs, entries: entries);
  }

  /// Saves the table model back to the JSON files in the folder.
  static Future<void> saveI18nFolder(
      String folderPath, I18nTableModel model) async {
    final Map<String, Map<String, String>> langToMap = {};
    for (final lang in model.languageCodes) {
      langToMap[lang] = {};
    }
    for (final entry in model.entries) {
      for (final lang in model.languageCodes) {
        final value = entry.translations[lang];
        if (value != null) {
          langToMap[lang]![entry.key] = value;
        }
      }
    }
    for (final lang in model.languageCodes) {
      final filename = lang == 'en'
          ? 'strings.i18n.json'
          : 'strings_${lang.toLowerCase()}.i18n.json';
      final file = File(p.join(folderPath, filename));
      final content =
          const JsonEncoder.withIndent('  ').convert(langToMap[lang]);
      await file.writeAsString(content);
    }
  }
}
