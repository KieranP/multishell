import Foundation
import MultishellCore

/// What `multishell tabs show` prints: one tab and its pane tree as laid out.
struct TabDescription: Encodable, Equatable {
  /// A pane, or a split of others with the share of the split each takes.
  struct Layout: Encodable, Equatable {
    let pane: TerminalSession.ID?
    /// In points from the window content's top left; `nil` for a pane not on screen.
    let frame: Frame?
    let axis: SplitAxis?
    /// Each child's part of the split, summing to 1; the tree keeps them relative.
    let shares: [Double]?
    let children: [Self]?
  }

  struct Frame: Encodable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
  }

  let id: TerminalTab.ID
  /// Its worktree's `ControlID`.
  let worktree: String
  let title: String
  /// On screen in its group.
  let isShown: Bool
  let focusedPane: TerminalSession.ID
  let state: SessionState?
  let layout: Layout
}
