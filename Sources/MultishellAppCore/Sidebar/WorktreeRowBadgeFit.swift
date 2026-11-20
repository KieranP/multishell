// Declared widest first, the order a crowded row tries them in.
// swiftlint:disable sorted_enum_cases
/// What a crowded worktree row keeps, giving up the terminal count, then the
/// services, then the git counts; a running or failed glyph always stays.
public enum WorktreeRowBadgeFit: Sendable {
  case all
  case withoutCount
  case withoutServices
  case alertsOnly

  public var showsGitState: Bool { self != .alertsOnly }

  public func showsCount(of terminalCount: Int) -> Bool {
    self == .all && TerminalCountCapsule.showsCount(of: terminalCount)
  }

  public func showsServices(_ services: WorktreeServices) -> Bool {
    (self == .all || self == .withoutCount) && services.showsAnything
  }
}
// swiftlint:enable sorted_enum_cases
