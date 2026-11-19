import AppKit

/// Takes keys in the recorder's window before the menus do, so ⌘W records ⌘W; a
/// click, or a key in another window, ends recording and goes on as usual.
@MainActor
final class ShortcutRecorderMonitor {
  private static let clicks: Set<NSEvent.EventType> = [
    .leftMouseDown, .rightMouseDown, .otherMouseDown,
  ]

  private var monitor: Any?

  init(windowNumber: Int?, onKey: @escaping (NSEvent) -> Void, onEnd: @escaping () -> Void) {
    monitor = NSEvent.addLocalMonitorForEvents(matching: [
      .keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]) {
      event in
      // A local monitor runs on the main thread, where the event already is.
      nonisolated(unsafe) let event = event
      let isTaken = MainActor.assumeIsolated {
        guard !Self.clicks.contains(event.type),
          Self.isTyped(event, inWindowNumbered: windowNumber)
        else {
          onEnd()
          return false
        }
        onKey(event)
        return true
      }
      return isTaken ? nil : event
    }
  }

  static func isTyped(_ event: NSEvent, inWindowNumbered windowNumber: Int?) -> Bool {
    event.windowNumber == windowNumber
  }

  isolated deinit {
    if let monitor { NSEvent.removeMonitor(monitor) }
  }
}
