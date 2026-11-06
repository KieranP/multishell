import AppKit
import Testing

@MainActor
func mouseEvent(
  _ type: NSEvent.EventType,
  at location: NSPoint,
  flags: NSEvent.ModifierFlags = [],
  in window: NSWindow? = nil,
) throws -> NSEvent {
  try #require(
    NSEvent.mouseEvent(
      with: type,
      location: location,
      modifierFlags: flags,
      timestamp: 1,
      windowNumber: window?.windowNumber ?? 0,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1,
    )
  )
}
