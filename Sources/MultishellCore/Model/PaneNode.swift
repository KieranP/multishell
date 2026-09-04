import Foundation

public enum SplitAxis: String, Codable, Hashable, Sendable {
  case horizontal
  case vertical
}

/// The arrangement of terminals inside one tab.
///
/// Today every tab is a single `.terminal`, because the MVP has no splits.
/// Modelling the tree now means adding them later touches the renderer and one
/// store method rather than the shape of persisted state.
public indirect enum PaneNode: Codable, Hashable, Sendable {
  case terminal(TerminalSession.ID)
  case split(axis: SplitAxis, children: [PaneNode], weights: [Double])

  public static func split(axis: SplitAxis, children: [PaneNode]) -> PaneNode {
    .split(axis: axis, children: children, weights: Array(repeating: 1, count: children.count))
  }
}

// MARK: - Traversal

extension PaneNode {
  public var sessionIDs: [TerminalSession.ID] {
    switch self {
    case .terminal(let id):
      return [id]
    case .split(_, let children, _):
      return children.flatMap(\.sessionIDs)
    }
  }

  public var isLeaf: Bool {
    if case .terminal = self { return true }
    return false
  }

  public func contains(_ id: TerminalSession.ID) -> Bool {
    sessionIDs.contains(id)
  }

  /// Drops a terminal from the tree, collapsing any split left with a single
  /// child. Returns `nil` when nothing is left.
  public func removing(_ id: TerminalSession.ID) -> PaneNode? {
    switch self {
    case .terminal(let existing):
      return existing == id ? nil : self

    case .split(let axis, let children, let weights):
      var survivors: [PaneNode] = []
      var survivingWeights: [Double] = []
      for (child, weight) in zip(children, weights) {
        guard let kept = child.removing(id) else { continue }
        survivors.append(kept)
        survivingWeights.append(weight)
      }
      switch survivors.count {
      case 0: return nil
      case 1: return survivors[0]
      default: return .split(axis: axis, children: survivors, weights: survivingWeights)
      }
    }
  }

  /// Splits the terminal `id` in half to make room for `newSession`.
  ///
  /// Splitting along the axis of the enclosing split adds a sibling rather
  /// than nesting, the way tmux and iTerm do: the pane's share is halved and
  /// the new pane takes the other half. A different axis nests.
  public func splitting(
    _ id: TerminalSession.ID,
    with newSession: TerminalSession.ID,
    axis: SplitAxis
  ) -> PaneNode {
    switch self {
    case .terminal(let existing):
      guard existing == id else { return self }
      return .split(axis: axis, children: [.terminal(existing), .terminal(newSession)])

    case .split(let axis0, let children, let weights):
      if axis0 == axis, let index = children.firstIndex(of: .terminal(id)) {
        var newChildren = children
        var newWeights = weights
        newChildren.insert(.terminal(newSession), at: index + 1)
        newWeights[index] /= 2
        newWeights.insert(newWeights[index], at: index + 1)
        return .split(axis: axis0, children: newChildren, weights: newWeights)
      }
      let updated = children.map { $0.splitting(id, with: newSession, axis: axis) }
      return .split(axis: axis0, children: updated, weights: weights)
    }
  }

  /// Replaces the weights of the split at `path` (child indices from the
  /// root). Anything else is returned unchanged.
  public func settingWeights(_ newWeights: [Double], at path: [Int]) -> PaneNode {
    guard case .split(let axis, let children, let weights) = self else { return self }
    guard let head = path.first else {
      return newWeights.count == children.count
        ? .split(axis: axis, children: children, weights: newWeights)
        : self
    }
    guard children.indices.contains(head) else { return self }
    var updated = children
    updated[head] = children[head].settingWeights(newWeights, at: Array(path.dropFirst()))
    return .split(axis: axis, children: updated, weights: weights)
  }
}
