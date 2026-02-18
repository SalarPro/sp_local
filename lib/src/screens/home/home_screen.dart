import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/data_grid_widget.dart';
import 'widgets/status_bar_widget.dart';
import 'widgets/toolbar_widget.dart';

class HomePage extends ConsumerStatefulWidget {
  /// A [FocusNode] for the search field, passed in from MyApp
  /// so keyboard shortcuts can focus it.
  final FocusNode searchFocusNode;

  const HomePage({super.key, required this.searchFocusNode});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Toolbar
          ToolbarWidget(searchFocusNode: widget.searchFocusNode),
          // DataGrid (main content)
          const Expanded(child: DataGridWidget()),
          // Status bar
          const StatusBarWidget(),
        ],
      ),
    );
  }
}
