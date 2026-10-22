import SwiftTreeSitter

extension Node {
  /// Lazy, and a cursor's walk: `child(at:)` scans from the first child on every call.
  var children: some Sequence<Node> {
    sequence(state: (cursor: treeCursor, isStarted: false)) { state in
      let moved = state.isStarted ? state.cursor.gotoNextSibling() : state.cursor.goToFirstChild()
      state.isStarted = true
      return moved ? state.cursor.currentNode : nil
    }
  }
}
