import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intent declarations for keyboard shortcuts.
class SaveIntent extends Intent {
  const SaveIntent();
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SearchFocusIntent extends Intent {
  const SearchFocusIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class DeleteRowIntent extends Intent {
  const DeleteRowIntent();
}

class AddKeyIntent extends Intent {
  const AddKeyIntent();
}

/// Returns the keyboard shortcut bindings (platform-aware: Cmd on macOS, Ctrl elsewhere).
Map<ShortcutActivator, Intent> get appShortcuts => {
      // Save
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
          const SaveIntent(),
      const SingleActivator(LogicalKeyboardKey.keyS, control: true):
          const SaveIntent(),
      // Undo
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
          const UndoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
          const UndoIntent(),
      // Redo
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
          const RedoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyZ,
          control: true, shift: true): const RedoIntent(),
      // Search
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          const SearchFocusIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          const SearchFocusIntent(),
      // Escape
      const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
      // Add key
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const AddKeyIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const AddKeyIntent(),
    };
