import MultishellCore

/// The quick switcher while it is up. Runtime state, gone when it closes.
public struct QuickSwitcherState: Equatable, Sendable {
  public internal(set) var scope: QuickSwitcherScope
  public internal(set) var text = ""
  /// The row the keyboard is on; `nil`, or a row no longer listed, is the first.
  var selected: QuickSwitcherTarget?
  /// The pointer chose `selected`, which neither scrolls nor is announced.
  var isSelectedByPointer = false
  /// Each arrow press, so one at either end still brings its row into view.
  var arrowPresses = 0
  /// The menu bar's enabled items as it opened, walked once, as each walk
  /// validates every item of every menu.
  let commands: [PlatformMenuItem]
  /// The worktree whose files it has asked to read since it opened.
  var filesAskedFor: Worktree.ID?
}
