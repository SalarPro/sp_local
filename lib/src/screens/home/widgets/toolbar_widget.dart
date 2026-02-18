import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/i18n_models.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/search_provider.dart';
import '../../../services/i18n_service.dart';

class ToolbarWidget extends ConsumerStatefulWidget {
  final FocusNode searchFocusNode;

  const ToolbarWidget({super.key, required this.searchFocusNode});

  @override
  ConsumerState<ToolbarWidget> createState() => _ToolbarWidgetState();
}

class _ToolbarWidgetState extends ConsumerState<ToolbarWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchProvider.notifier).state =
          ref.read(searchProvider).copyWith(query: value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).state =
        ref.read(searchProvider).copyWith(query: '');
  }

  Future<void> _pickFolder() async {
    final unsaved = ref.read(unsavedProvider);
    if (unsaved) {
      final result = await _showUnsavedDialog();
      if (result == null) return; // cancelled
      if (result == 'save') {
        await ref.read(projectProvider.notifier).save();
      }
      // 'discard' — continue without saving
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      await ref.read(projectProvider.notifier).loadFolder(selectedDirectory);
    }
  }

  Future<void> _reload() async {
    final unsaved = ref.read(unsavedProvider);
    if (unsaved) {
      final result = await _showUnsavedDialog();
      if (result == null) return;
      if (result == 'save') {
        await ref.read(projectProvider.notifier).save();
      }
    }
    await ref.read(projectProvider.notifier).reload();
  }

  Future<void> _save() async {
    await ref.read(projectProvider.notifier).save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved successfully!'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<String?> _showUnsavedDialog() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content:
            const Text('You have unsaved changes. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddKeyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Key name',
            hintText: 'e.g. homeTitle',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (I18nService.isValidKey(value)) {
              ref.read(projectProvider.notifier).addEntry(value);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final key = controller.text;
              if (I18nService.isValidKey(key)) {
                ref.read(projectProvider.notifier).addEntry(key);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showAddLanguageDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Language'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Language code',
            hintText: 'e.g. fr, de, es',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final code = value.trim().toLowerCase();
            if (code.isNotEmpty) {
              ref.read(projectProvider.notifier).addLanguage(code);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim().toLowerCase();
              if (code.isNotEmpty) {
                ref.read(projectProvider.notifier).addLanguage(code);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final unsaved = ref.watch(unsavedProvider);
    final hasProject = ref.watch(projectProvider).valueOrNull != null;
    final notifier = ref.watch(projectProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          // Open folder
          _ToolbarButton(
            icon: Icons.folder_open,
            tooltip: 'Open Folder',
            onPressed: _pickFolder,
          ),
          if (hasProject) ...[
            const SizedBox(width: 4),
            _ToolbarButton(
              icon: Icons.refresh,
              tooltip: 'Reload',
              onPressed: _reload,
            ),
            const SizedBox(width: 4),
            // Save button with unsaved indicator
            Stack(
              children: [
                _ToolbarButton(
                  icon: Icons.save,
                  tooltip: 'Save (${_cmdKey}S)',
                  onPressed: _save,
                ),
                if (unsaved)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Undo/Redo
            _ToolbarButton(
              icon: Icons.undo,
              tooltip: 'Undo (${_cmdKey}Z)',
              onPressed: notifier.canUndo ? () => notifier.undo() : null,
            ),
            const SizedBox(width: 4),
            _ToolbarButton(
              icon: Icons.redo,
              tooltip: 'Redo (${_cmdKey}Shift+Z)',
              onPressed: notifier.canRedo ? () => notifier.redo() : null,
            ),
            const SizedBox(width: 12),
            // Search field
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  focusNode: widget.searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search keys & values...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Search scope dropdown
            SizedBox(
              height: 36,
              child: DropdownButton<SearchScope>(
                value: search.scope,
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: SearchScope.both,
                    child: Text('All', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: SearchScope.key,
                    child: Text('Keys', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: SearchScope.value,
                    child: Text('Values', style: TextStyle(fontSize: 12)),
                  ),
                ],
                onChanged: (scope) {
                  if (scope != null) {
                    ref.read(searchProvider.notifier).state =
                        search.copyWith(scope: scope);
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            // Case sensitivity toggle
            _ToolbarToggle(
              icon: Icons.text_fields,
              tooltip: 'Case Sensitive',
              isActive: search.caseSensitive,
              onPressed: () {
                ref.read(searchProvider.notifier).state =
                    search.copyWith(caseSensitive: !search.caseSensitive);
              },
            ),
            const SizedBox(width: 4),
            // Missing translations filter
            _ToolbarToggle(
              icon: Icons.warning_amber,
              tooltip: 'Show Missing Only',
              isActive: search.showMissingOnly,
              onPressed: () {
                ref.read(searchProvider.notifier).state =
                    search.copyWith(showMissingOnly: !search.showMissingOnly);
              },
            ),
            const SizedBox(width: 12),
            // Add key
            _ToolbarButton(
              icon: Icons.add,
              tooltip: 'Add Key (${_cmdKey}N)',
              onPressed: _showAddKeyDialog,
            ),
            const SizedBox(width: 4),
            // Add language
            _ToolbarButton(
              icon: Icons.language,
              tooltip: 'Add Language',
              onPressed: _showAddLanguageDialog,
            ),
            const SizedBox(width: 4),
            // Copy slang command
            _ToolbarButton(
              icon: Icons.terminal,
              tooltip: 'Copy "flutter pub run slang"',
              onPressed: () {
                Clipboard.setData(
                    const ClipboardData(text: 'flutter pub run slang'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String get _cmdKey {
    // macOS uses Cmd, Windows/Linux uses Ctrl
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    return isMacOS ? '\u2318' : 'Ctrl+';
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _ToolbarToggle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const _ToolbarToggle({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor:
              isActive ? Theme.of(context).colorScheme.primaryContainer : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
