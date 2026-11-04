import Foundation
import MultishellCore

extension SidebarPane {
  /// The state at the row's right edge, the board card's rail. None for idle,
  /// where most shells rest, so the edge speaks only for a pane doing something.
  public var railState: SessionState? {
    state == .idle ? nil : state
  }

  /// How long the pane has been in its state, as a board card says it.
  public func elapsed(at now: Date) -> String? {
    railState == nil ? nil : ElapsedText.short(since: since, now: now)
  }
}
