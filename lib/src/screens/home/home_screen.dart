import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  int? editingRow;
  String? editingLang;

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
    tableModel!.entries.add(I18nStringEntry(
        key: '',
        translations: {for (var lang in tableModel!.languageCodes) lang: ''}));
    setState(() {});
    //scroll to the bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
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
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(
                    const ClipboardData(text: "flutter pub run slang"));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
              tooltip: 'RUN',
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
                              : scrollBarWidget(),
                        ),
                      ],
                    ),
    );
  }

  Scrollbar scrollBarWidget() {
    return Scrollbar(
      thumbVisibility: true,
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: tableModel!.entries.length,
        itemBuilder: (context, i) {
          final entry = tableModel!.entries[i];
          if (search.length > 3 && !entry.key.contains(search)) {
            return const SizedBox.shrink();
          }
          final rowColor = !isValidKey(entry.key)
              ? Colors.red[100]
              : entry.translations.values.any((v) => (v ?? '').isEmpty)
                  ? Colors.yellow[50]
                  : null;
          return cellsWidget(rowColor, i, entry);
        },
      ),
    );
  }

  Container cellsWidget(Color? rowColor, int i, I18nStringEntry entry) {
    return Container(
      color: rowColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: (editingRow == i && editingLang == null)
                  ? TextFormField(
                      initialValue: entry.key,
                      autofocus: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        isDense: true,
                        errorText: entry.key.isEmpty || isValidKey(entry.key)
                            ? null
                            : 'Invalid',
                      ),
                      style: const TextStyle(fontSize: 12),
                      onFieldSubmitted: (_) => setState(() {
                        editingRow = null;
                        editingLang = null;
                      }),
                      maxLines: null,
                      minLines: null,
                      onChanged: (v) {
                        entry.key = v;
                        setState(() {});
                      },
                    )
                  : GestureDetector(
                      onTap: () => setState(() {
                        editingRow = i;
                        editingLang = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: rowColor != null
                                ? Colors.orangeAccent
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
            ),
          ),
          ...tableModel!.languageCodes.map((lang) {
            final missing = (entry.translations[lang] ?? '').isEmpty;
            final isRtl = rtlLangs.contains(lang);
            final isEditing = editingRow == i && editingLang == lang;
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: isEditing
                    ? editingTextWidget(entry, lang, missing, isRtl)
                    : onlyShowText(i, lang, missing, isRtl, entry),
              ),
            );
          }),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Duplicate',
                  onPressed: () => duplicateKey(i),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  onPressed: () => removeKey(i),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  GestureDetector onlyShowText(
      int i, String lang, bool missing, bool isRtl, I18nStringEntry entry) {
    return GestureDetector(
      onTap: () => setState(() {
        editingRow = i;
        editingLang = lang;
      }),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 50,
        ), // Added this line
        decoration: BoxDecoration(
          border: Border.all(
            color: missing ? Colors.yellow.shade700 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          entry.translations[lang] ?? '',
          style: const TextStyle(fontSize: 12),
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        ),
      ),
    );
  }

  TextFormField editingTextWidget(
      I18nStringEntry entry, String lang, bool missing, bool isRtl) {
    return TextFormField(
      initialValue: entry.translations[lang] ?? '',
      autofocus: true,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        fillColor: missing ? Colors.yellow[100] : null,
        filled: missing,
      ),
      minLines: null,
      maxLines: null,
      style: const TextStyle(fontSize: 12),
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      onFieldSubmitted: (_) => setState(() {
        editingRow = null;
        editingLang = null;
      }),
      onChanged: (v) {
        entry.translations[lang] = v;
        setState(() {});
      },
    );
  }
}
