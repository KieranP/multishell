import Foundation
import MultishellCore

extension AgentBoardCard {
  /// What the occupant last said about itself, or what a finished command
  /// amounted to. Absent for a pane that has said nothing.
  public var message: String? {
    guard let note = note?.matching(state) else { return nil }
    if let message = note.message, !message.isEmpty { return message }
    guard let duration = note.duration, let text = ElapsedText.precise(duration) else { return nil }
    switch note.state {
    case .done: return t("card.done", text)
    case .failed: return t("card.failed", text)
    case .running, .attention, .idle: return nil
    }
  }

  /// How long it has been in its column.
  public func elapsed(at now: Date) -> String? {
    ElapsedText.short(since: since, now: now)
  }
}
