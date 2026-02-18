/// A generic undo/redo stack for immutable state objects.
class UndoStack<T> {
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];
  final int maxHistory;

  UndoStack({this.maxHistory = 100});

  /// Push a new state onto the stack. Clears the redo stack.
  void push(T state) {
    _undoStack.add(state);
    _redoStack.clear();
    // Limit history size
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  /// Undo: pops the current state, pushes it to redo, returns the previous state.
  /// Returns null if there's nothing to undo.
  T? undo(T currentState) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(currentState);
    return _undoStack.removeLast();
  }

  /// Redo: pops from the redo stack, pushes current to undo, returns the redo state.
  /// Returns null if there's nothing to redo.
  T? redo(T currentState) {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(currentState);
    return _redoStack.removeLast();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Clear all history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;
}
