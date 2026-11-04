/// Whether a worktree row's count capsule is drawn, with its room: a row with no
/// terminals draws neither. See Docs/design/agents.md.
public enum TerminalCountCapsule {
  public static func showsCount(of terminalCount: Int) -> Bool {
    terminalCount > 0
  }
}
