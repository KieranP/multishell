extension PaneNode {
  /// Drops a terminal from the tree, collapsing any split left with a single
  /// child. Returns `nil` when nothing is left.
  func removing(_ id: TerminalSession.ID) -> PaneNode? {
    pruning { $0 == id }
  }

  /// Drops every terminal `shouldDrop` names, in display order, collapsing
  /// the splits that leaves. `nil` when nothing is left.
  func pruning(_ shouldDrop: (TerminalSession.ID) -> Bool) -> PaneNode? {
    switch self {
    case .terminal(let id):
      return shouldDrop(id) ? nil : self

    case .split(let axis, let children, let weights):
      let aligned = LayoutWeight.aligned(weights, count: children.count)
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
  func splitting(
    _ id: TerminalSession.ID,
    with newSession: TerminalSession.ID,
    axis: SplitAxis,
  ) -> PaneNode {
    switch self {
    case .terminal(let existing):
      guard existing == id else { return self }
      return .split(axis: axis, children: [.terminal(existing), .terminal(newSession)])

    case .split(let existingAxis, let children, let weights):
      if existingAxis == axis, let index = children.firstIndex(of: .terminal(id)) {
        var newChildren = children
        var newWeights = LayoutWeight.aligned(weights, count: children.count)
        newChildren.insert(.terminal(newSession), at: index + 1)
        newWeights[index] /= 2
        newWeights.insert(newWeights[index], at: index + 1)
        return .split(axis: existingAxis, children: newChildren, weights: newWeights)
      }
      let updated = children.map { $0.splitting(id, with: newSession, axis: axis) }
      return .split(axis: existingAxis, children: updated, weights: weights)
    }
  }

  /// Replaces the weights of the split at `path` (child indices from the
  /// root). Anything else is returned unchanged.
  func settingWeights(_ newWeights: [Double], at path: [Int]) -> PaneNode {
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
