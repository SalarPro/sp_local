import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/i18n_models.dart';
import '../models/undo_history.dart';
import '../services/i18n_service.dart';

/// Tracks whether there are unsaved changes.
final unsavedProvider = StateProvider<bool>((ref) => false);

/// The main project state notifier — manages loading, editing, saving.
final projectProvider =
    StateNotifierProvider<ProjectNotifier, AsyncValue<I18nProject?>>(
  (ref) => ProjectNotifier(ref),
);

class ProjectNotifier extends StateNotifier<AsyncValue<I18nProject?>> {
  final Ref ref;
  final UndoStack<I18nProject> _undoStack = UndoStack(maxHistory: 50);

  ProjectNotifier(this.ref) : super(const AsyncValue.data(null));

  I18nProject? get project => state.valueOrNull;

  bool get canUndo => _undoStack.canUndo;
  bool get canRedo => _undoStack.canRedo;

  /// Load a folder of i18n JSON files.
  Future<void> loadFolder(String path) async {
    state = const AsyncValue.loading();
    try {
      final project = await I18nService.loadI18nFolder(path);
      state = AsyncValue.data(project);
      _undoStack.clear();
      ref.read(unsavedProvider.notifier).state = false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Reload the current folder.
  Future<void> reload() async {
    final currentProject = project;
    if (currentProject == null) return;
    await loadFolder(currentProject.folderPath);
  }

  /// Save the current project to disk.
  Future<void> save() async {
    final currentProject = project;
    if (currentProject == null) return;
    await I18nService.saveI18nFolder(currentProject);
    ref.read(unsavedProvider.notifier).state = false;
  }

  /// Push current state to undo stack before making a change.
  void _pushUndo() {
    final currentProject = project;
    if (currentProject == null) return;
    _undoStack.push(currentProject);
    ref.read(unsavedProvider.notifier).state = true;
  }

  /// Update a single entry's translation value.
  void updateTranslation(int entryIndex, String lang, String? value) {
    final currentProject = project;
    if (currentProject == null) return;
    if (entryIndex < 0 || entryIndex >= currentProject.entries.length) return;

    _pushUndo();

    final entries = List<I18nEntry>.from(currentProject.entries);
    final oldEntry = entries[entryIndex];
    final newTranslations = Map<String, String?>.from(oldEntry.translations);
    newTranslations[lang] = value;
    entries[entryIndex] = oldEntry.copyWith(translations: newTranslations);

    state = AsyncValue.data(currentProject.copyWith(entries: entries));
  }

  /// Update a single entry's key.
  void updateKey(int entryIndex, String newKey) {
    final currentProject = project;
    if (currentProject == null) return;
    if (entryIndex < 0 || entryIndex >= currentProject.entries.length) return;

    _pushUndo();

    final entries = List<I18nEntry>.from(currentProject.entries);
    entries[entryIndex] = entries[entryIndex].copyWith(key: newKey);
    state = AsyncValue.data(currentProject.copyWith(entries: entries));
  }

  /// Add a new entry with the given key.
  void addEntry(String key) {
    final currentProject = project;
    if (currentProject == null) return;

    _pushUndo();

    final translations = <String, String?>{
      for (var lang in currentProject.languages) lang: '',
    };
    final entries = List<I18nEntry>.from(currentProject.entries)
      ..add(I18nEntry(key: key, translations: translations));

    state = AsyncValue.data(currentProject.copyWith(entries: entries));
  }

  /// Delete an entry at the given index.
  void deleteEntry(int entryIndex) {
    final currentProject = project;
    if (currentProject == null) return;
    if (entryIndex < 0 || entryIndex >= currentProject.entries.length) return;

    _pushUndo();

    final entries = List<I18nEntry>.from(currentProject.entries)
      ..removeAt(entryIndex);
    state = AsyncValue.data(currentProject.copyWith(entries: entries));
  }

  /// Duplicate an entry at the given index.
  void duplicateEntry(int entryIndex) {
    final currentProject = project;
    if (currentProject == null) return;
    if (entryIndex < 0 || entryIndex >= currentProject.entries.length) return;

    _pushUndo();

    final entries = List<I18nEntry>.from(currentProject.entries);
    final original = entries[entryIndex];
    final copy = original.copyWith(key: '${original.key}_copy');
    entries.insert(entryIndex + 1, copy);

    state = AsyncValue.data(currentProject.copyWith(entries: entries));
  }

  /// Add a new language column.
  Future<void> addLanguage(String langCode) async {
    final currentProject = project;
    if (currentProject == null) return;
    if (currentProject.languages.contains(langCode)) return;

    _pushUndo();

    final languages = List<String>.from(currentProject.languages)
      ..add(langCode);
    final entries = currentProject.entries.map((entry) {
      final translations = Map<String, String?>.from(entry.translations);
      translations[langCode] = '';
      return entry.copyWith(translations: translations);
    }).toList();

    // Create the file on disk
    await I18nService.addLanguageFile(
      currentProject.folderPath,
      langCode,
      currentProject.entries,
    );

    state = AsyncValue.data(
      currentProject.copyWith(languages: languages, entries: entries),
    );
  }

  /// Remove a language column and its file.
  Future<void> removeLanguage(String langCode) async {
    final currentProject = project;
    if (currentProject == null) return;
    if (!currentProject.languages.contains(langCode)) return;

    _pushUndo();

    final languages = List<String>.from(currentProject.languages)
      ..remove(langCode);
    final entries = currentProject.entries.map((entry) {
      final translations = Map<String, String?>.from(entry.translations);
      translations.remove(langCode);
      return entry.copyWith(translations: translations);
    }).toList();

    // Delete the file from disk
    await I18nService.removeLanguageFile(currentProject.folderPath, langCode);

    state = AsyncValue.data(
      currentProject.copyWith(languages: languages, entries: entries),
    );
  }

  /// Undo the last change.
  void undo() {
    final currentProject = project;
    if (currentProject == null) return;
    final previous = _undoStack.undo(currentProject);
    if (previous != null) {
      state = AsyncValue.data(previous);
      // If undo stack is empty, mark as not unsaved
      if (!_undoStack.canUndo) {
        ref.read(unsavedProvider.notifier).state = false;
      }
    }
  }

  /// Redo a previously undone change.
  void redo() {
    final currentProject = project;
    if (currentProject == null) return;
    final next = _undoStack.redo(currentProject);
    if (next != null) {
      state = AsyncValue.data(next);
      ref.read(unsavedProvider.notifier).state = true;
    }
  }
}
