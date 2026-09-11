import Foundation
import MultishellCore

/// One open pane, as everything the board needs to know about it.
///
/// The model gathers these from the workspace, the states and the registry;
/// `AgentBoard` decides the arrangement and `AgentBoardOrder` the order.
/// Flattening a pane to this is what keeps both testable without a
/// workspace, a host or a clock: the time a card shows is derived from
/// `since` and a `now` handed in, never read here.
public struct AgentBoardCard: Identifiable, Equatable, Sendable {
  /// What is at the pane's prompt. An agent is named by the catalogue; a
  /// shell by its own file name, which is all a shell has to say for itself.
  public enum Occupant: Equatable, Sendable {
    case agent(String)
    case shell(String)

    public var name: String {
      switch self {
      case .agent(let name), .shell(let name): name
      }
    }

    public var isAgent: Bool {
      if case .agent = self { return true }
      return false
    }
  }

  public let id: TerminalSession.ID
  public let tabID: TerminalTab.ID
  public let worktreeID: Worktree.ID
  public let occupant: Occupant
  /// What the tab strip calls this pane's tab, which for a shell running a
  /// command is usually the command.
  public let title: String
  public let projectName: String
  public let worktreeName: String
  /// `nil` for a pane with nothing to report, which is what Idle means.
  public let state: SessionState?
  /// When it entered that state, absent for a pane that has never left it.
  public let since: Date?
  public let note: SessionNote?
  public let status: WorktreeStatus?

  public var lane: AgentBoardLane { AgentBoardLane.of(state) }

  /// The line under the place: what the occupant last said about itself, or
  /// what a finished command amounted to. Absent for a pane that has said
  /// nothing, which is most of Working and all of Idle.
  public var message: String? {
    guard let note = note?.describing(state) else { return nil }
    if let message = note.message, !message.isEmpty { return message }
    guard let duration = note.duration, let text = ElapsedText.precise(duration) else { return nil }
    switch note.state {
    case .done: return t("card.done", text)
    case .error: return t("card.failed", text)
    case .running, .attention, .idle: return nil
    }
  }

  /// How long it has been in its column, spelled for the card's corner.
  ///
  /// `now` is the board's held clock and lags by up to its tick, so a pane
  /// that entered its column since the last one has a `since` in the future.
  /// Clamped rather than passed on: `ElapsedText` reads a negative interval
  /// as a clock moved backwards and gives nothing back, which would blank
  /// the corner of the one card that just changed until the next tick.
  public func elapsed(at now: Date) -> String? {
    guard let since else { return nil }
    return ElapsedText.short(since: since, now: max(now, since))
  }
}
