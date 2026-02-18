import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/project_provider.dart';
import '../../../providers/search_provider.dart';
import '../../../providers/table_provider.dart';

class StatusBarWidget extends ConsumerWidget {
  const StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider).valueOrNull;
    final totalCount = ref.watch(totalEntryCountProvider);
    final filteredCount = ref.watch(filteredEntryCountProvider);
    final searchFilter = ref.watch(searchProvider);
    final unsaved = ref.watch(unsavedProvider);

    if (project == null) return const SizedBox.shrink();

    final isFiltered = searchFilter.isActive;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Unsaved indicator
          if (unsaved) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Modified',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
            const SizedBox(width: 16),
          ],

          // Entry count
          Icon(Icons.list, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            isFiltered
                ? '$filteredCount / $totalCount entries'
                : '$totalCount entries',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),

          const SizedBox(width: 16),

          // Language count
          Icon(Icons.language, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '${project.languages.length} languages (${project.languages.join(", ")})',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),

          const Spacer(),

          // Folder path
          Icon(Icons.folder_outlined, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              project.folderPath,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
