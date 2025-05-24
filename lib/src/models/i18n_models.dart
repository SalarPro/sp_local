class I18nStringEntry {
  String key;
  Map<String, String?> translations; // languageCode -> value

  I18nStringEntry({required this.key, required this.translations});
}

class I18nTableModel {
  final List<String> languageCodes; // e.g. ['en', 'ar', 'ku']
  final List<I18nStringEntry> entries;

  I18nTableModel({required this.languageCodes, required this.entries});
}
