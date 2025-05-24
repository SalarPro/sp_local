import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/i18n_models.dart';
import '../../services/i18n_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? i18nFolderPath;
  I18nTableModel? tableModel;
  String search = '';
  bool loading = false;
  String? error;
  final ScrollController _scrollController = ScrollController();

  static const rtlLangs = {'ar', 'fa', 'he', 'ku', 'ks', 'ur'};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> pickI18nFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        i18nFolderPath = selectedDirectory;
        loading = true;
        error = null;
      });
      try {
        final model = await I18nService.loadI18nFolder(selectedDirectory);
        setState(() {
          tableModel = model;
          loading = false;
        });
      } catch (e) {
        setState(() {
          error = 'Failed to load: $e';
          loading = false;
        });
      }
    }
  }

  void reload() {
    if (i18nFolderPath != null) {
      pickI18nFolder();
    }
  }

  void save() async {
    if (i18nFolderPath != null && tableModel != null) {
      setState(() => loading = true);
      await I18nService.saveI18nFolder(i18nFolderPath!, tableModel!);
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved!')));
    }
  }

  void addKey() {
    if (tableModel == null) return;
    setState(() {
      tableModel!.entries.add(I18nStringEntry(key: '', translations: {
        for (var lang in tableModel!.languageCodes) lang: ''
      }));
    });
  }

  void removeKey(int index) {
    setState(() {
      tableModel!.entries.removeAt(index);
    });
  }

  void duplicateKey(int index) {
    final entry = tableModel!.entries[index];
    setState(() {
      tableModel!.entries.insert(
          index + 1,
          I18nStringEntry(
            key: entry.key + 'Copy',
            translations: Map<String, String?>.from(entry.translations),
          ));
    });
  }

  bool isValidKey(String key) {
    final reg = RegExp(r'^[a-z][a-zA-Z0-9_]*$');
    return reg.hasMatch(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('i18n Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: pickI18nFolder,
            tooltip: 'Select i18n Folder',
          ),
          if (i18nFolderPath != null) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: reload,
              tooltip: 'Reload',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: save,
              tooltip: 'Save',
            ),
          ]
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : i18nFolderPath == null
              ? const Center(child: Text('Select an i18n folder to begin.'))
              : error != null
                  ? Center(child: Text(error!))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Search keys',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (v) => setState(() => search = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add Key'),
                                onPressed: addKey,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: tableModel == null
                              ? const Center(child: Text('No data'))
                              : Scrollbar(
                                  thumbVisibility: true,
                                  controller: _scrollController,
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    itemCount: tableModel!.entries.length,
                                    itemBuilder: (context, i) {
                                      final entry = tableModel!.entries[i];
                                      if (search.isNotEmpty &&
                                          !entry.key.contains(search))
                                        return const SizedBox.shrink();
                                      final rowColor = !isValidKey(entry.key)
                                          ? Colors.red[100]
                                          : entry.translations.values
                                                  .any((v) => (v ?? '').isEmpty)
                                              ? Colors.yellow[50]
                                              : null;
                                      return Container(
                                        color: rowColor,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 200,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                child: TextFormField(
                                                  initialValue: entry.key,
                                                  decoration: InputDecoration(
                                                    border:
                                                        const OutlineInputBorder(),
                                                    isDense: true,
                                                    errorText:
                                                        entry.key.isEmpty ||
                                                                isValidKey(
                                                                    entry.key)
                                                            ? null
                                                            : 'Invalid',
                                                  ),
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                  onChanged: (v) {
                                                    entry.key = v;
                                                    setState(() {});
                                                  },
                                                ),
                                              ),
                                            ),
                                            ...tableModel!.languageCodes
                                                .map((lang) {
                                              final missing =
                                                  (entry.translations[lang] ??
                                                          '')
                                                      .isEmpty;
                                              final isRtl =
                                                  rtlLangs.contains(lang);
                                              return Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 2),
                                                  child: TextFormField(
                                                    initialValue:
                                                        entry.translations[
                                                                lang] ??
                                                            '',
                                                    decoration: InputDecoration(
                                                      border:
                                                          const OutlineInputBorder(),
                                                      isDense: true,
                                                      fillColor: missing
                                                          ? Colors.yellow[100]
                                                          : null,
                                                      filled: missing,
                                                    ),
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                    textDirection: isRtl
                                                        ? TextDirection.rtl
                                                        : TextDirection.ltr,
                                                    onChanged: (v) {
                                                      entry.translations[lang] =
                                                          v;
                                                      setState(() {});
                                                    },
                                                    minLines: null,
                                                    maxLines: null,
                                                  ),
                                                ),
                                              );
                                            }),
                                            SizedBox(
                                              width: 100,
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon:
                                                        const Icon(Icons.copy),
                                                    tooltip: 'Duplicate',
                                                    onPressed: () =>
                                                        duplicateKey(i),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete),
                                                    tooltip: 'Delete',
                                                    onPressed: () =>
                                                        removeKey(i),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }
}
