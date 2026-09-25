import AppKit

/// A window never ordered in, which lays a view out and draws it without asking for anything.
@MainActor
enum OffscreenWindow {
  /// `rect` defaults to the content's own frame.
  static func holding(_ content: NSView, rect: NSRect? = nil, deferred: Bool = true) -> NSWindow {
    let window = NSWindow(
      contentRect: rect ?? content.frame, styleMask: [.titled], backing: .buffered,
      defer: deferred)
    window.contentView = content
    content.layoutSubtreeIfNeeded()
    return window
  }

  /// `run(until:)` returns at once while the main run loop has no source, so the wait is
  /// looped, until `done` or `limit`.
  static func settle(until done: () -> Bool = { false }, within limit: TimeInterval) {
    let deadline = Date().addingTimeInterval(limit)
    while !done(), Date() < deadline {
      RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
  }
}
