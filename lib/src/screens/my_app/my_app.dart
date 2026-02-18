import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/i18n_models.dart';
import '../../providers/project_provider.dart';
import '../../providers/search_provider.dart';
import '../../services/keyboard_shortcuts.dart';
import '../home/home_screen.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sp_local — i18n Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'ibm_arabic',
        visualDensity: VisualDensity.compact,
        // Dense desktop styling
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      home: Shortcuts(
        shortcuts: appShortcuts,
        child: Actions(
          actions: {
            SaveIntent: CallbackAction<SaveIntent>(
              onInvoke: (_) async {
                await ref.read(projectProvider.notifier).save();
                return null;
              },
            ),
            UndoIntent: CallbackAction<UndoIntent>(
              onInvoke: (_) {
                ref.read(projectProvider.notifier).undo();
                return null;
              },
            ),
            RedoIntent: CallbackAction<RedoIntent>(
              onInvoke: (_) {
                ref.read(projectProvider.notifier).redo();
                return null;
              },
            ),
            SearchFocusIntent: CallbackAction<SearchFocusIntent>(
              onInvoke: (_) {
                _searchFocusNode.requestFocus();
                return null;
              },
            ),
            EscapeIntent: CallbackAction<EscapeIntent>(
              onInvoke: (_) {
                // Clear search on Escape
                ref.read(searchProvider.notifier).state = const SearchFilter();
                _searchFocusNode.unfocus();
                return null;
              },
            ),
            AddKeyIntent: CallbackAction<AddKeyIntent>(
              onInvoke: (_) {
                // Focus will be handled by the toolbar
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: HomePage(searchFocusNode: _searchFocusNode),
          ),
        ),
      ),
    );
  }
}
