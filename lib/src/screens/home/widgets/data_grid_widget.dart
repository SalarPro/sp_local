import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../models/i18n_models.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/table_provider.dart';
import '../../../services/i18n_service.dart';

class DataGridWidget extends ConsumerStatefulWidget {
  const DataGridWidget({super.key});

  @override
  ConsumerState<DataGridWidget> createState() => _DataGridWidgetState();
}

class _DataGridWidgetState extends ConsumerState<DataGridWidget> {
  I18nDataSource? _dataSource;
  final DataGridController _gridController = DataGridController();

  @override
  void dispose() {
    _dataSource?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectProvider);
    final filteredEntries = ref.watch(filteredEntriesProvider);

    return projectAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      data: (project) {
        if (project == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Select an i18n folder to begin.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Use the folder icon in the toolbar or press Cmd/Ctrl+O',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Create or update data source
        _dataSource = I18nDataSource(
          entries: filteredEntries,
          languages: project.languages,
          onTranslationChanged: (originalIndex, lang, value) {
            ref
                .read(projectProvider.notifier)
                .updateTranslation(originalIndex, lang, value);
          },
          onKeyChanged: (originalIndex, newKey) {
            ref.read(projectProvider.notifier).updateKey(originalIndex, newKey);
          },
          onDelete: (originalIndex) {
            _showDeleteConfirmation(context, originalIndex);
          },
          onDuplicate: (originalIndex) {
            ref.read(projectProvider.notifier).duplicateEntry(originalIndex);
          },
          onRemoveLanguage: (lang) {
            _showRemoveLanguageConfirmation(context, lang);
          },
        );

        return SfDataGrid(
          source: _dataSource!,
          controller: _gridController,
          gridLinesVisibility: GridLinesVisibility.both,
          headerGridLinesVisibility: GridLinesVisibility.both,
          allowEditing: true,
          navigationMode: GridNavigationMode.cell,
          selectionMode: SelectionMode.single,
          editingGestureType: EditingGestureType.doubleTap,
          frozenColumnsCount: 1,
          columnWidthMode: ColumnWidthMode.fill,
          allowSorting: true,
          allowMultiColumnSorting: false,
          onCellDoubleTap: (_) {},
          headerRowHeight: 40,
          rowHeight: 42,
          columns: [
            // Key column (frozen)
            GridColumn(
              columnName: 'key',
              label: _buildHeaderCell('Key', isKey: true),
              minimumWidth: 200,
              width: 250,
              allowEditing: true,
              allowSorting: true,
            ),
            // Language columns
            ...project.languages.map((lang) {
              final isRtl = I18nService.isRtl(lang);
              return GridColumn(
                columnName: lang,
                label: _buildLanguageHeaderCell(lang, isRtl),
                minimumWidth: 150,
                allowEditing: true,
                allowSorting: true,
              );
            }),
            // Actions column
            GridColumn(
              columnName: '_actions',
              label: _buildHeaderCell('Actions'),
              width: 90,
              allowEditing: false,
              allowSorting: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderCell(String text, {bool isKey = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: isKey ? Colors.blue.shade800 : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLanguageHeaderCell(String lang, bool isRtl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            lang.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: isRtl ? Colors.teal.shade700 : null,
            ),
          ),
          if (isRtl) ...[
            const SizedBox(width: 4),
            Icon(Icons.format_textdirection_r_to_l,
                size: 14, color: Colors.teal.shade700),
          ],
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int originalIndex) {
    final project = ref.read(projectProvider).valueOrNull;
    if (project == null) return;
    final entry = project.entries[originalIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete key "${entry.key}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(projectProvider.notifier).deleteEntry(originalIndex);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRemoveLanguageConfirmation(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Language'),
        content: Text(
            'Remove language "$lang"? This will delete the file from disk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(projectProvider.notifier).removeLanguage(lang);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

/// DataSource for the Syncfusion DataGrid.
/// Maps filtered/sorted [IndexedEntry] items to grid rows, using the
/// originalIndex to dispatch edits to the correct entry in the project.
class I18nDataSource extends DataGridSource {
  final List<IndexedEntry> entries;
  final List<String> languages;
  final void Function(int originalIndex, String lang, String? value)
      onTranslationChanged;
  final void Function(int originalIndex, String newKey) onKeyChanged;
  final void Function(int originalIndex) onDelete;
  final void Function(int originalIndex) onDuplicate;
  final void Function(String lang) onRemoveLanguage;

  List<DataGridRow> _rows = [];

  /// Editing state
  dynamic _newCellValue;

  I18nDataSource({
    required this.entries,
    required this.languages,
    required this.onTranslationChanged,
    required this.onKeyChanged,
    required this.onDelete,
    required this.onDuplicate,
    required this.onRemoveLanguage,
  }) {
    _buildRows();
  }

  void _buildRows() {
    _rows = entries.map((indexed) {
      final cells = <DataGridCell>[
        DataGridCell<String>(columnName: 'key', value: indexed.entry.key),
        ...languages.map((lang) => DataGridCell<String>(
              columnName: lang,
              value: indexed.entry.translations[lang] ?? '',
            )),
        DataGridCell<int>(columnName: '_actions', value: indexed.originalIndex),
      ];
      return DataGridRow(cells: cells);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final cells = row.getCells();
    final keyCell = cells.first;
    final isInvalidKey = keyCell.value.toString().isEmpty ||
        !I18nService.isValidKey(keyCell.value.toString());

    // Check for missing translations
    final hasMissing = cells
        .where((c) => c.columnName != 'key' && c.columnName != '_actions')
        .any((c) => (c.value?.toString() ?? '').isEmpty);

    final bgColor = isInvalidKey
        ? Colors.red.shade50
        : hasMissing
            ? Colors.amber.shade50
            : null;

    return DataGridRowAdapter(
      color: bgColor,
      cells: cells.map((cell) {
        if (cell.columnName == '_actions') {
          final originalIndex = cell.value as int;
          return _ActionsCell(
            onDuplicate: () => onDuplicate(originalIndex),
            onDelete: () => onDelete(originalIndex),
          );
        }

        final isRtl = I18nService.isRtl(cell.columnName);
        final isKey = cell.columnName == 'key';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            cell.value?.toString() ?? '',
            style: TextStyle(
              fontSize: 12,
              fontFamily: isKey ? 'firacode' : null,
              color: isKey ? Colors.blue.shade900 : null,
            ),
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget? buildEditWidget(DataGridRow dataGridRow,
      RowColumnIndex rowColumnIndex, GridColumn column, CellSubmit submitCell) {
    final columnName = column.columnName;
    if (columnName == '_actions') return null;

    final currentValue = dataGridRow
            .getCells()
            .firstWhere((c) => c.columnName == columnName)
            .value
            ?.toString() ??
        '';

    _newCellValue = currentValue;
    final isRtl = I18nService.isRtl(columnName);
    final isKey = columnName == 'key';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextField(
        controller: TextEditingController(text: currentValue),
        autofocus: true,
        style: TextStyle(
          fontSize: 12,
          fontFamily: isKey ? 'firacode' : null,
        ),
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        maxLines: null,
        onChanged: (value) {
          _newCellValue = value;
        },
        onSubmitted: (_) => submitCell(),
      ),
    );
  }

  @override
  Future<void> onCellSubmit(DataGridRow dataGridRow,
      RowColumnIndex rowColumnIndex, GridColumn column) async {
    final rowIndex = rowColumnIndex.rowIndex - 1; // header offset
    if (rowIndex < 0 || rowIndex >= entries.length) return;

    final indexed = entries[rowIndex];
    final columnName = column.columnName;
    final newValue = _newCellValue?.toString() ?? '';

    if (columnName == 'key') {
      onKeyChanged(indexed.originalIndex, newValue);
    } else if (columnName != '_actions') {
      onTranslationChanged(indexed.originalIndex, columnName, newValue);
    }
  }
}

/// Actions cell with duplicate and delete buttons.
class _ActionsCell extends StatelessWidget {
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ActionsCell({
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            icon: const Icon(Icons.copy, size: 14),
            tooltip: 'Duplicate',
            onPressed: onDuplicate,
            padding: EdgeInsets.zero,
          ),
        ),
        SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
            tooltip: 'Delete',
            onPressed: onDelete,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
