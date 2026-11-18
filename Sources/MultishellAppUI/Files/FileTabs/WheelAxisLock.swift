import AppKit

/// One gesture's axis, kept from its first moving frame through its momentum: chosen
/// a frame at a time, a sideways swipe was split between a file and the list.
struct WheelAxisLock {
  private var lockedVertical: Bool?

  mutating func isVertical(
    dx sideways: CGFloat,
    dy down: CGFloat,
    phase: NSEvent.Phase,
    momentumPhase: NSEvent.Phase,
  ) -> Bool {
    let leansVertical = abs(down) >= abs(sideways)
    guard !phase.isEmpty || !momentumPhase.isEmpty else { return leansVertical }
    if phase.contains(.began) || phase.contains(.mayBegin) { lockedVertical = nil }
    if lockedVertical == nil, sideways != 0 || down != 0 { lockedVertical = leansVertical }
    return lockedVertical ?? true
  }
}
