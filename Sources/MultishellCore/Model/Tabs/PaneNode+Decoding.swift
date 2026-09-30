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
  /// not line up: the pane view lays children out by weight index.
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
    guard weights.count == children.count, LayoutWeight.allUsable(weights) else {
      self = .split(axis: axis, children: children)
      return
    }
    self = .split(axis: axis, children: children, weights: weights)
  }
}
