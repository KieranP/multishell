import Foundation

public enum SplitAxis: String, Codable, Hashable, Sendable {
  case horizontal
  case vertical
}

/// The arrangement of terminals inside one tab: a leaf per terminal, a split
/// per divider, with the weights a divider drag writes back.
public indirect enum PaneNode: Codable, Hashable, Sendable {
  case terminal(TerminalSession.ID)
  case split(axis: SplitAxis, children: [PaneNode], weights: [Double])

  public static func split(axis: SplitAxis, children: [PaneNode]) -> PaneNode {
    .split(axis: axis, children: children, weights: Array(repeating: 1, count: children.count))
  }
}

// MARK: - Decoding

extension PaneNode {
  private enum RootKeys: String, CodingKey {
    case terminal
    case split
  }

  private enum TerminalKeys: String, CodingKey {
    case _0
  }

  private enum SplitKeys: String, CodingKey {
    case axis
    case children
    case weights
  }

  /// Reads the synthesized shape, tolerating weights that are missing or do
  /// not line up: `removing` zips them, so a mismatch would drop panes.
  public init(from decoder: any Decoder) throws {
    let root = try decoder.container(keyedBy: RootKeys.self)
    if root.contains(.terminal) {
      let terminal = try root.nestedContainer(keyedBy: TerminalKeys.self, forKey: .terminal)
      self = .terminal(try terminal.decode(TerminalSession.ID.self, forKey: ._0))
      return
    }
    let split = try root.nestedContainer(keyedBy: SplitKeys.self, forKey: .split)
    let axis = split.decodeTolerantly(SplitAxis.self, forKey: .axis, or: .horizontal)
    let children = try split.decode([PaneNode].self, forKey: .children)
    let weights = try split.decode([Double].self, forKey: .weights, or: [])
    guard weights.count == children.count, weights.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
      self = .split(axis: axis, children: children)
      return
    }
    self = .split(axis: axis, children: children, weights: weights)
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
    pruning { $0 == id }
  }

  /// Drops every terminal `shouldDrop` names, in display order, collapsing
  /// the splits that leaves. `nil` when nothing is left.
  public func pruning(_ shouldDrop: (TerminalSession.ID) -> Bool) -> PaneNode? {
    switch self {
    case .terminal(let id):
      return shouldDrop(id) ? nil : self

    case .split(let axis, let children, let weights):
      let aligned =
        weights.count == children.count ? weights : Array(repeating: 1, count: children.count)
      var survivors: [PaneNode] = []
      var survivingWeights: [Double] = []
      for (child, weight) in zip(children, aligned) {
        guard let kept = child.pruning(shouldDrop) else { continue }
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

  /// Splits the terminal `id` in half for `newSession`. The enclosing
  /// split's own axis adds a sibling, as tmux does; another axis nests.
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
        // Indexed by child, so weights that do not line up become equal
        // shares here rather than a trap; `pruning` makes the same choice.
        var newWeights =
          weights.count == children.count ? weights : Array(repeating: 1, count: children.count)
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
