import Foundation

/// A tab as a state file spells it, with no group: one pane holding `session`,
/// or the pane tree `root` spells.
func tabJSON(
  id: UUID = UUID(),
  worktree: String = "/repos/demo",
  session: UUID = UUID(),
  root: String? = nil,
) -> String {
  let paneTree = root ?? #"{ "terminal": { "_0": "\#(session)" } }"#
  return #"""
    { "id": "\#(id)", "worktreeID": "\#(worktree)",
      "root": \#(paneTree), "focusedSessionID": "\#(session)" }
    """#
}
