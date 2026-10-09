import AppKit

/// A command key's release and a click that only brings a window forward reach
/// no view, so one monitor for the whole app hands each to the pane it is for.
@MainActor
final class GhosttyPaneEventMonitor {
  private let monitor: Any?

  init() {
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .leftMouseDown]) { event in
      // A local monitor runs on the main thread, where the event already is.
      nonisolated(unsafe) let event = event
      let isTaken = MainActor.assumeIsolated { Self.deliver(event) }
      return isTaken ? nil : event
    }
  }

  /// `true` where a pane took the event, which AppKit then never sees.
  static func deliver(_ event: NSEvent) -> Bool {
    guard let window = event.window else { return false }
    if event.type == .keyUp {
      return (window.firstResponder as? GhosttySurfaceView)?.takeCommandKeyUp(event) ?? false
    }
    guard let pane = view(at: event.locationInWindow, in: window) as? GhosttySurfaceView
    else { return false }
    pane.focusOnActivatingClick(event)
    return false
  }

  /// `hitTest` takes a point in the superview's space; in the content view's
  /// own, which a SwiftUI window flips, a stacked split's panes swap.
  static func view(at locationInWindow: NSPoint, in window: NSWindow) -> NSView? {
    guard let content = window.contentView else { return nil }
    let point = content.superview?.convert(locationInWindow, from: nil) ?? locationInWindow
    return content.hitTest(point)
  }

  isolated deinit {
    if let monitor { NSEvent.removeMonitor(monitor) }
  }
}
