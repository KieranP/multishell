import AppKit
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

/// Answers `hitTest` only while a middle-button event is being routed, so
/// the taps, the drag and the buttons SwiftUI draws underneath all keep
/// their own clicks. It registers no dragged types either, so a drop passes
/// it by.
///
/// The action runs on mouse up inside the view, the way every tab strip
/// closes: pressing and dragging off the tab is not a close.
private final class MiddleClickView: NSView {
  var action: (() -> Void)?

  override init(frame: NSRect) {
    super.init(frame: frame)
    // Not an element of its own, or VoiceOver would read an unlabelled item
    // inside every tab it covers.
    setAccessibilityElement(false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

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
