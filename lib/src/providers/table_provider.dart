import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/i18n_models.dart';
import 'project_provider.dart';
import 'search_provider.dart';

/// Derived provider that computes the filtered and sorted entries list.
/// Each entry preserves its original index in the project entries list,
/// which is critical for correct editing when search/sort is active.
final filteredEntriesProvider = Provider<List<IndexedEntry>>((ref) {
  final projectAsync = ref.watch(projectProvider);
  final search = ref.watch(searchProvider);
  final sort = ref.watch(sortProvider);

  final project = projectAsync.valueOrNull;
  if (project == null) return [];

  // Index all entries first
  List<IndexedEntry> indexed = [];
  for (int i = 0; i < project.entries.length; i++) {
    indexed.add(IndexedEntry(
      originalIndex: i,
      entry: project.entries[i],
    ));
  }

  // Apply search filter
  if (search.query.isNotEmpty) {
    indexed = indexed.where((ie) {
      return ie.entry.matchesSearch(
        search.query,
        search.scope,
        search.caseSensitive,
      );
    }).toList();
  }

  // Apply missing translations filter
  if (search.showMissingOnly) {
    indexed = indexed.where((ie) => ie.entry.hasMissingTranslations).toList();
  }

  // Apply sort
  indexed.sort((a, b) {
    int cmp;
    if (sort.column == 'key') {
      cmp = a.entry.key.compareTo(b.entry.key);
    } else {
      // Sort by a language column value
      final aVal = a.entry.translations[sort.column] ?? '';
      final bVal = b.entry.translations[sort.column] ?? '';
      cmp = aVal.compareTo(bVal);
    }
    return sort.ascending ? cmp : -cmp;
  });

  return indexed;
});

/// Total entry count (unfiltered).
final totalEntryCountProvider = Provider<int>((ref) {
  final project = ref.watch(projectProvider).valueOrNull;
  return project?.entries.length ?? 0;
});

/// Filtered entry count.
final filteredEntryCountProvider = Provider<int>((ref) {
  return ref.watch(filteredEntriesProvider).length;
});
