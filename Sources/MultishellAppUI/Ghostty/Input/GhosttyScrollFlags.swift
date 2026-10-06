import AppKit
import GhosttyKit

/// libghostty's packed scroll flags: bit 0 a precise device such as a
/// trackpad, bits 1-3 the momentum phase, in `ghostty_input_mouse_momentum_e`.
struct GhosttyScrollFlags {
  let rawValue: ghostty_input_scroll_mods_t

  init(_ event: NSEvent) {
    self.init(isPrecise: event.hasPreciseScrollingDeltas, momentum: event.momentumPhase)
  }

  init(isPrecise: Bool, momentum: NSEvent.Phase) {
    let phase = Self.phase(momentum).rawValue
    rawValue = (isPrecise ? 1 : 0) | ghostty_input_scroll_mods_t(phase) << 1
  }

  private static func phase(_ momentum: NSEvent.Phase) -> ghostty_input_mouse_momentum_e {
    switch momentum {
    case .began: GHOSTTY_MOUSE_MOMENTUM_BEGAN
    case .stationary: GHOSTTY_MOUSE_MOMENTUM_STATIONARY
    case .changed: GHOSTTY_MOUSE_MOMENTUM_CHANGED
    case .ended: GHOSTTY_MOUSE_MOMENTUM_ENDED
    case .cancelled: GHOSTTY_MOUSE_MOMENTUM_CANCELLED
    case .mayBegin: GHOSTTY_MOUSE_MOMENTUM_MAY_BEGIN
    default: GHOSTTY_MOUSE_MOMENTUM_NONE
    }
  }
}
