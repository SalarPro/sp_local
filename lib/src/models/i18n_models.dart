/// Immutable data models for the i18n editor.
library;

/// Represents a single localization entry with a key and translations
/// across multiple languages.
class I18nEntry {
  final String key;
  final Map<String, String?> translations; // languageCode -> value

  const I18nEntry({
    required this.key,
    required this.translations,
  });

  I18nEntry copyWith({
    String? key,
    Map<String, String?>? translations,
  }) {
    return I18nEntry(
      key: key ?? this.key,
      translations: translations ?? Map.from(this.translations),
    );
  }

  /// Whether this entry has any missing (null or empty) translations.
  bool get hasMissingTranslations =>
      translations.values.any((v) => v == null || v.isEmpty);

  /// Check if this entry matches a search query.
  bool matchesSearch(String query, SearchScope scope, bool caseSensitive) {
    if (query.isEmpty) return true;

    final q = caseSensitive ? query : query.toLowerCase();

    if (scope == SearchScope.key || scope == SearchScope.both) {
      final k = caseSensitive ? key : key.toLowerCase();
      if (k.contains(q)) return true;
    }

    if (scope == SearchScope.value || scope == SearchScope.both) {
      for (final value in translations.values) {
        if (value == null) continue;
        final v = caseSensitive ? value : value.toLowerCase();
        if (v.contains(q)) return true;
      }
    }

    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is I18nEntry &&
          key == other.key &&
          _mapsEqual(translations, other.translations);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(translations.entries));

  static bool _mapsEqual(Map<String, String?> a, Map<String, String?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Represents the entire loaded i18n project state.
class I18nProject {
  final String folderPath;
  final List<String> languages;
  final List<I18nEntry> entries;

  const I18nProject({
    required this.folderPath,
    required this.languages,
    required this.entries,
  });

  I18nProject copyWith({
    String? folderPath,
    List<String>? languages,
    List<I18nEntry>? entries,
  }) {
    return I18nProject(
      folderPath: folderPath ?? this.folderPath,
      languages: languages ?? List.from(this.languages),
      entries: entries ?? List.from(this.entries),
    );
  }
}

/// Defines the scope of a search operation.
enum SearchScope { key, value, both }

/// Configuration for search/filter state.
class SearchFilter {
  final String query;
  final SearchScope scope;
  final bool caseSensitive;
  final bool showMissingOnly;

  const SearchFilter({
    this.query = '',
    this.scope = SearchScope.both,
    this.caseSensitive = false,
    this.showMissingOnly = false,
  });

  SearchFilter copyWith({
    String? query,
    SearchScope? scope,
    bool? caseSensitive,
    bool? showMissingOnly,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      scope: scope ?? this.scope,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      showMissingOnly: showMissingOnly ?? this.showMissingOnly,
    );
  }

  bool get isActive => query.isNotEmpty || showMissingOnly;
}

/// Configuration for sorting.
class SortConfig {
  final String column; // "key" or a language code
  final bool ascending;

  const SortConfig({
    this.column = 'key',
    this.ascending = true,
  });

  SortConfig copyWith({
    String? column,
    bool? ascending,
  }) {
    return SortConfig(
      column: column ?? this.column,
      ascending: ascending ?? this.ascending,
    );
  }
}

/// A filtered entry that preserves its original index in the entries list.
class IndexedEntry {
  final int originalIndex;
  final I18nEntry entry;

  const IndexedEntry({
    required this.originalIndex,
    required this.entry,
  });
}
