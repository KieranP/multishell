import SwiftUI

extension View {
  /// A middle click, which SwiftUI has no gesture for.
  func onMiddleClick(perform action: @escaping () -> Void) -> some View {
    overlay { MiddleClickCatcher(action: action) }
  }
}

private struct MiddleClickCatcher: NSViewRepresentable {
  let action: () -> Void

  func makeNSView(context: Context) -> MiddleClickView { MiddleClickView() }

  func updateNSView(_ view: MiddleClickView, context: Context) { view.action = action }
}

/// Answers `hitTest` only while a middle-button event is routed, so what is
/// drawn underneath keeps its clicks. The action runs on mouse up inside.
private final class MiddleClickView: AccessibilityHiddenView {
  var action: (() -> Void)?

  override func hitTest(_ point: NSPoint) -> NSView? {
    switch NSApp.currentEvent?.type {
    case .otherMouseDown, .otherMouseUp, .otherMouseDragged: super.hitTest(point)
    default: nil
    }
  }

  /// Taken rather than passed on, or the matching mouse up would be routed
  /// somewhere else and the close would never arrive.
  override func otherMouseDown(with event: NSEvent) {
    if event.buttonNumber != 2 { super.otherMouseDown(with: event) }
  }

  override func otherMouseUp(with event: NSEvent) {
    guard event.buttonNumber == 2 else { return super.otherMouseUp(with: event) }
    if bounds.contains(convert(event.locationInWindow, from: nil)) { action?() }
  }
}
