/// The arrangement of terminals inside one tab: a leaf per terminal, a split
/// per divider, with the weights a divider drag writes back.
public indirect enum PaneNode: Codable, Hashable, Sendable {
  case split(axis: SplitAxis, children: [Self], weights: [Double])
  case terminal(TerminalSession.ID)

  public var sessionIDs: [TerminalSession.ID] {
    switch self {
    case .terminal(let id):
      return [id]

    case .split(_, let children, _):
      return children.flatMap(\.sessionIDs)
    }
  }

  var isLeaf: Bool {
    if case .terminal = self { return true }
    return false
  }

  static func split(axis: SplitAxis, children: [Self]) -> Self {
    .split(
      axis: axis,
      children: children,
      weights: LayoutWeight.equalShares(count: children.count),
    )
  }

  public func contains(_ id: TerminalSession.ID) -> Bool {
    sessionIDs.contains(id)
  }
}
