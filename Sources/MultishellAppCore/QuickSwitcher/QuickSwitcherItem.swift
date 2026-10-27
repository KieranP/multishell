import Foundation
import MultishellCore
import MultishellGitKit

/// One row of the quick switcher, as everything the row draws.
public struct QuickSwitcherItem: Identifiable, Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    /// A pane with an agent at its prompt, by catalogue id.
    case agent(id: String)
    case command
    case file
    case fileTab
    /// A project, with what its icon is drawn from.
    case project(settings: ProjectSettings, isMissing: Bool)
    /// A pane with a shell at its prompt, not an agent.
    case shell
    case worktree

    var isAgent: Bool {
      if case .agent = self { true } else { false }
    }
  }

  /// Between a path's steps, which matching takes as a break between words.
  static let pathStep = "›"

  public let target: QuickSwitcherTarget
  public let kind: Kind
  /// A place's path from its project down, `billing › main › Claude Code`, or a
  /// file's or a command's name.
  public let title: String
  /// Read after the title: an agent pane's own title, a project's folder, a
  /// file's folder, or a command's menu.
  public let location: String
  /// The title's characters the typed text matched, by offset, which the row bolds.
  public internal(set) var titleOffsets: Set<Int> = []
  /// Which pane of a split, a renamed tab giving its panes one title.
  public let position: PanePosition?
  public let state: SessionState?
  /// When the pane entered its state, for how long an agent has waited.
  let since: Date?
  public let status: WorktreeStatus?
  /// The keys a command's menu item carries.
  public let shortcut: String?
  public let isChecked: Bool

  public var id: QuickSwitcherTarget { target }
  /// The state the row names beside its wait; Idle is said by nothing at all.
  public var labelledState: SessionState? { state == .idle ? nil : state }

  init(
    target: QuickSwitcherTarget,
    kind: Kind,
    title: String,
    location: String,
    position: PanePosition? = nil,
    state: SessionState? = nil,
    since: Date? = nil,
    status: WorktreeStatus? = nil,
    shortcut: String? = nil,
    isChecked: Bool = false,
  ) {
    self.target = target
    self.kind = kind
    self.title = title
    self.location = location
    self.position = position
    self.state = state
    self.since = since
    self.status = status
    self.shortcut = shortcut
    self.isChecked = isChecked
  }

  static func path(_ steps: some Sequence<String>) -> String {
    steps.joined(separator: " \(pathStep) ")
  }

  /// How long the pane has been in its state, as a board card says it.
  public func elapsed(at now: Date) -> String? {
    ElapsedText.short(since: since, now: now)
  }
}
