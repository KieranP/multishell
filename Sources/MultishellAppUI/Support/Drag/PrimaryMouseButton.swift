import AppKit

/// The mouse's primary button, read as it is asked. A value, not a closure the
/// environment cannot compare, so a test can hold it down.
struct PrimaryMouseButton: Equatable, Sendable {
  let isPressedOverride: Bool?

  @MainActor var isPressed: Bool { isPressedOverride ?? (NSEvent.pressedMouseButtons & 1 != 0) }

  init(isPressedOverride: Bool? = nil) {
    self.isPressedOverride = isPressedOverride
  }
}
