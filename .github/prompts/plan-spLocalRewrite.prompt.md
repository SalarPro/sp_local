## Plan: Full Rewrite of sp_local — Advanced Desktop i18n Editor

**TL;DR:** Complete rewrite of the localization JSON editor using Riverpod for state management and Syncfusion Flutter DataGrid for the spreadsheet. The current tool has critical bugs (search+edit corrupts data, folder picker crashes on macOS) and severe performance issues (full `ListView` rebuild on every keystroke for 2000+ rows with no virtualization). The rewrite delivers a professional desktop-grade tool with keyboard shortcuts, undo/redo, value search, column sorting/filtering, language management, and unsaved-changes protection.

---

**Steps**

### 1. Fix macOS Entitlements (prerequisite — unblocks folder picker)
- In [macos/Runner/DebugProfile.entitlements](macos/Runner/DebugProfile.entitlements), add key `com.apple.security.files.user-selected.read-write` = `true`
- In [macos/Runner/Release.entitlements](macos/Runner/Release.entitlements), add the same key
- This resolves the `PlatformException(ENTITLEMENT_NOT_FOUND)` error

### 2. Update Dependencies in [pubspec.yaml](pubspec.yaml)
- Remove `provider` (unused)
- Add `flutter_riverpod` (^2.6.x) for state management
- Add `syncfusion_flutter_datagrid` (latest) for the Excel-like table
- Add `riverpod_annotation` + `build_runner` + `custom_lint` as dev deps for code-gen (optional but recommended)
- Keep `file_picker` and `path`

### 3. New Project Structure
Reorganize [lib/](lib/) to:
```
lib/
  main.dart                          # ProviderScope wrapper → MyApp
  src/
    models/
      i18n_models.dart               # Immutable data models (I18nEntry, I18nLanguage, I18nProject)
      undo_history.dart              # UndoStack<I18nProject> with redo support
    providers/
      project_provider.dart          # StateNotifier<I18nProject?> — load/save/edit
      search_provider.dart           # StateProvider<SearchFilter> — query + scope (key/value/both)
      table_provider.dart            # Derived provider: filtered + sorted entries list
      undo_provider.dart             # Wraps undo_history, exposes undo/redo actions
      ui_state_provider.dart         # Tracks unsaved changes flag, selected folder path, loading
    screens/
      home/
        home_screen.dart             # Scaffold: toolbar + SfDataGrid + status bar
        widgets/
          toolbar_widget.dart        # Search field, sort/filter, add key, save, open folder
          data_grid_widget.dart      # Syncfusion DataGrid wrapper + cell editing
          status_bar_widget.dart     # Entry count, unsaved indicator, current folder
      my_app/
        my_app.dart                  # MaterialApp, theme, shortcuts
    services/
      i18n_service.dart             # Async file I/O: loadFolder(), saveFolder(), addLanguage(), removeLanguage()
      keyboard_shortcuts.dart       # Intent/Action bindings for Cmd+S, Cmd+Z, Cmd+Shift+Z, Cmd+F, Tab, Escape
```

### 4. Immutable Data Models — [lib/src/models/i18n_models.dart](lib/src/models/i18n_models.dart)
- `I18nEntry` — immutable class with `key` (String), `translations` (Map<String, String?>) and `copyWith()`
- `I18nProject` — immutable class with `folderPath`, `languages` (List<String>), `entries` (List<I18nEntry>), `copyWith()`
- Remove old mutable `I18nStringEntry` and `I18nTableModel`
- Add `UndoStack<T>` class in `undo_history.dart`: stores a list of past states + future states, exposes `push(state)`, `undo()`, `redo()`, `canUndo`, `canRedo`

### 5. Async I/O Service — [lib/src/services/i18n_service.dart](lib/src/services/i18n_service.dart)
- Rewrite `loadI18nFolder()` to use **async** `file.readAsString()` instead of `readAsStringSync()` — prevents UI freezes on large folders
- Use `Isolate.run()` (or `compute()`) for JSON parsing of large files — offload from UI thread
- Rewrite `saveI18nFolder()` as async, also using `Isolate.run()` for JSON encoding
- Add `addLanguageFile(folderPath, langCode)` — creates a new `strings_xx.i18n.json` with all existing keys set to `null`
- Add `removeLanguageFile(folderPath, langCode)` — deletes the file after confirmation
- Fix: when saving, write `""` (empty string) for keys that exist but have no translation, instead of dropping them entirely. This preserves the key in all language files

### 6. Riverpod Providers — [lib/src/providers/](lib/src/providers/)

- **`projectProvider`** (`StateNotifier<AsyncValue<I18nProject?>>`)
  - `loadFolder(path)` → calls service, pushes to undo stack, clears unsaved flag
  - `updateEntry(index, I18nEntry)` → updates entry at index, pushes to undo stack, sets unsaved=true
  - `addEntry(key)` → appends new entry with null translations
  - `deleteEntry(index)` → removes entry
  - `duplicateEntry(index)` → copies entry with `_copy` suffix
  - `updateKey(index, newKey)` → renames key with validation
  - `addLanguage(code)` / `removeLanguage(code)`
  - `save()` → calls service, clears unsaved flag

- **`searchProvider`** (`StateProvider<SearchFilter>`)
  - `SearchFilter` has `query` (String), `scope` (enum: key, value, both), `caseSensitive` (bool)

- **`filteredEntriesProvider`** (derived)
  - Watches `projectProvider` + `searchProvider` + `sortProvider`
  - Returns `List<(int originalIndex, I18nEntry entry)>` — filtered and sorted
  - The `originalIndex` field is critical: it maps visible rows back to the real entry list, **preventing the search+edit bug**

- **`sortProvider`** (`StateProvider<SortConfig>`)
  - `SortConfig` has `column` (String — "key" or a language code), `ascending` (bool)

- **`undoProvider`** — wraps `UndoStack`, exposes `undo()`, `redo()`, `canUndo`, `canRedo`

- **`unsavedProvider`** (`StateProvider<bool>`) — toggled by edits, cleared by save/load

### 7. Syncfusion DataGrid — [lib/src/screens/home/widgets/data_grid_widget.dart](lib/src/screens/home/widgets/)

- Create a `I18nDataSource extends DataGridSource`:
  - Override `rows` getter → builds `DataGridRow` from `filteredEntriesProvider`
  - First column: "Key" (frozen/pinned, ~250px)
  - Dynamic columns: one per language code (expandable width)
  - Last column: "Actions" (duplicate, delete buttons, ~100px)
  - Override `onCellSubmit()` to dispatch edits to `projectProvider` using the **original index** from the filtered list
  - Override `buildEditWidget()` for inline cell editing with `TextField`
  
- DataGrid features to enable:
  - `allowEditing: true` (double-click or F2 to edit)
  - `frozenColumnsCount: 1` (pin Key column)
  - `allowSorting: true` on all columns
  - `columnWidthMode` auto or fill
  - `selectionMode: SelectionMode.single`
  - Virtual scrolling is built-in — handles 2000+ rows effortlessly

- The DataGrid handles virtualization natively, so only visible rows are built. This is the **primary performance fix**.

### 8. Toolbar — [lib/src/screens/home/widgets/toolbar_widget.dart](lib/src/screens/home/widgets/)
- **Search field**: debounced (300ms) text input → updates `searchProvider`. Includes a dropdown to select scope (key/value/both) and a case-sensitivity toggle
- **Open Folder** button
- **Reload** button (reloads current folder, warns if unsaved)
- **Save** button (with unsaved indicator dot)
- **Add Key** button (inline dialog with key validation using existing regex)
- **Add Language** button (dialog to enter language code)
- **Filter chips**: "Missing translations" toggle — filters to entries where any language has `null`

### 9. Keyboard Shortcuts — [lib/src/services/keyboard_shortcuts.dart](lib/src/services/keyboard_shortcuts.dart)
- Register at `MyApp` level using `Shortcuts` + `Actions` widgets
- `Cmd+S` / `Ctrl+S` → save
- `Cmd+Z` / `Ctrl+Z` → undo
- `Cmd+Shift+Z` / `Ctrl+Shift+Z` → redo
- `Cmd+F` / `Ctrl+F` → focus search field
- `Escape` → clear search / deselect
- `Tab` → move to next cell (Syncfusion handles this natively with `navigationMode: GridNavigationMode.cell`)
- `Delete` → delete selected row (with confirmation)

### 10. Unsaved Changes Protection
- In `MyApp`, wrap with a window-close listener (use `window_manager` package or Flutter's `AppLifecycleListener`)
- On folder switch or app close: if `unsavedProvider` is true, show a dialog: "You have unsaved changes. Save / Discard / Cancel"
- On reload: same dialog

### 11. Status Bar — [lib/src/screens/home/widgets/status_bar_widget.dart](lib/src/screens/home/widgets/)
- Shows: total entries count, filtered count (if searching), number of languages, current folder path, unsaved indicator
- Lightweight `Consumer` widget watching only relevant providers

### 12. App Shell & Theme — [lib/src/screens/my_app/my_app.dart](lib/src/screens/my_app/my_app.dart)
- Wrap root with `ProviderScope`
- Desktop-optimized theme: smaller padding, denser DataGrid rows
- Keep existing font configuration (IBM Plex Sans Arabic + FiraCode for monospace cells)
- Consider adding `macos_ui` or `fluent_ui` for native look (optional stretch goal)

### 13. Cleanup
- Remove unused `provider` dependency
- Remove all old screen/model/service files once rewrite is complete
- Update [analysis_options.yaml](analysis_options.yaml) if needed for Riverpod lints

---

**Verification**

1. **macOS folder picker**: Run on macOS, tap "Open Folder" — should open picker without `PlatformException`
2. **Large file performance**: Load a folder with ~2000-key JSON files — grid should scroll smoothly at 60fps, search should filter without lag (debounced, virtualized)
3. **Search + edit correctness**: Search for a term, edit a visible cell, save, reload — verify the correct key was modified in the JSON file
4. **Undo/Redo**: Edit a value → Cmd+Z should revert → Cmd+Shift+Z should re-apply
5. **Keyboard shortcuts**: Cmd+S saves, Cmd+F focuses search, Tab navigates cells
6. **Add/remove language**: Add a new language → new column appears → save → new JSON file created on disk
7. **Unsaved warning**: Edit a value → try to close/switch folder → warning dialog appears
8. **Sort/filter**: Click column header to sort; toggle "Missing translations" filter

**Decisions**
- **Full rewrite over refactor**: Current architecture (mutable state + `setState` + non-virtualized `ListView`) makes incremental fixes unreliable; a rewrite with proper foundations is cleaner and faster
- **Syncfusion DataGrid over data_table_2**: Built-in cell editing, virtual scrolling, frozen columns, sorting — matches the Excel-like UX goal
- **Riverpod over Provider/Bloc**: Compile-safe, great derived state support, pairs well with immutable models
- **Original-index tracking in filtered list**: This is the key architectural fix for the search+edit corruption bug — every filtered row carries its index into the canonical entries list
- **Async I/O + isolates**: Prevents UI thread blocking for large JSON files
- **Debounced search**: 300ms debounce prevents rebuilds on every keystroke
