import AppKit
import SwiftUI

extension View {
  /// `cursor` while the pointer is over this view, popped when it leaves and
  /// when the view goes: `onHover(false)` never fires for a view that has.
  func cursorPush(_ cursor: NSCursor) -> some View {
    modifier(CursorPush(cursor: cursor))
  }
}

private struct CursorPush: ViewModifier {
  let cursor: NSCursor

  @State private var pushed = false

  func body(content: Content) -> some View {
    content
      .onHover { inside in
        guard inside != pushed else { return }
        pushed = inside
        if inside { cursor.push() } else { NSCursor.pop() }
      }
      .onDisappear {
        guard pushed else { return }
        pushed = false
        NSCursor.pop()
      }
  }
}
