import CoreGraphics
import Foundation
import MultishellCore

/// What dragging a divider or a panel's edge sets. Shares are relative, as
/// the tree keeps them; `tabs show` and `tabs list` print them summing to 1.
extension AppModel {
  /// One share a side, each leaving its side at least what a drag would where the
  /// length is known and has room for every side's least, as a drag needs.
  private static func refusalToTake(
    _ shares: [Double],
    count: Int,
    across length: Double?,
  ) -> ControlRefusal? {
    guard shares.count == count else { return .wrongShareCount(expected: count) }
    guard LayoutWeight.allUsable(shares) else {
      return .invalidValue(
        key: "SHARE",
        value: shares.map { String(format: "%g", $0) }.joined(separator: " "),
      )
    }
    let minimum = SplitMath.minimumPaneLength
    let roomyLength = length.flatMap { $0 >= minimum * Double(count) ? $0 : nil }
    let lengths = roomyLength.map { SplitMath.sizes(of: shares, sharing: $0) } ?? []
    guard lengths.contains(where: { $0 < minimum }) else { return nil }
    return .shareBelowMinimum(points: minimum)
  }

  /// The dividers of the split at `path`, `[]` its root: each child of the split
  /// takes its share, in the order `tabs show` lists them.
  func replyToResizeSplit(
    _ shares: [Double],
    at path: [Int],
    ofTab id: TerminalTab.ID,
  ) -> ControlReply {
    let tab: TerminalTab
    do { tab = try reachTerminalTab(id) } catch { return .refused(error) }
    guard let split = tab.root.split(at: path) else {
      return .refused(.noSplit(id: id, path: path))
    }
    let length = laidOutLength(ofSides: split.children.map(\.sessionIDs), along: split.axis)
    if let refusal = Self.refusalToTake(shares, count: split.children.count, across: length) {
      return .refused(refusal)
    }
    setSplitWeights(shares, at: path, ofTab: id)
    return replyToDescribeTab(id)
  }

  /// The dividers between a worktree's groups, left to right.
  func replyToResizeGroups(_ shares: [Double], in id: String) -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    let groups = workspace.groups(in: worktree.id)
    guard !groups.isEmpty else { return .refused(.noGroups(id: id)) }
    let shownPanes = groups.map { workspace.shownTab(ofGroup: $0)?.root.sessionIDs }
    // A group showing a file has no frames, so its width is not known.
    let length =
      shownPanes.contains(nil)
      ? nil : laidOutLength(ofSides: shownPanes.compactMap(\.self), along: .horizontal)
    if let refusal = Self.refusalToTake(shares, count: groups.count, across: length) {
      return .refused(refusal)
    }
    setGroupWeights(shares, in: worktree.id)
    return .done
  }

  /// Held to what a drag could reach: the sidebar to the window less an open Files
  /// panel and the tab area's least; the panel narrowed by a small window as after a drag.
  func replyToSetPanelWidth(_ panel: ResizablePanel, to width: Double) -> ControlReply {
    guard let windowWidth = platform.workspaceWindowWidth else { return .refused(.noWindow) }
    let range =
      switch panel {
      case .filesPanel: FilesPanelWidth.minimum...FilesPanelWidth.maximum

      case .sidebar:
        SidebarWidth.range(
          inWindowOfWidth: windowWidth,
          besidePanelOf: isFilesPanelOnScreen ? platform.width(of: .filesPanel) : 0,
        )
      }
    guard range.contains(width) else {
      return .refused(.widthOutOfRange(minimum: range.lowerBound, maximum: range.upperBound))
    }
    return platform.setWidth(of: panel, to: width) ? .done : .refused(.noWindow)
  }

  /// The sides' lengths along `axis` as laid out, summed, so the dividers between
  /// them are left out; `nil` where a pane is off screen.
  private func laidOutLength(
    ofSides sides: [[TerminalSession.ID]],
    along axis: SplitAxis,
  ) -> Double? {
    var total = 0.0
    for side in sides {
      let frames = side.compactMap(host.frame(of:))
      guard let first = frames.first, frames.count == side.count else { return nil }
      let span = frames.dropFirst().reduce(first) { $0.union($1) }
      total += axis == .horizontal ? span.width : span.height
    }
    return sides.isEmpty ? nil : total
  }
}
