/// The arrangement of terminals inside one tab: a leaf per terminal, a split
/// per divider, with the weights a divider drag writes back.
public indirect enum PaneNode: Codable, Hashable, Sendable {
  case terminal(TerminalSession.ID)
  case split(axis: SplitAxis, children: [PaneNode], weights: [Double])

  static func split(axis: SplitAxis, children: [PaneNode]) -> PaneNode {
    .split(axis: axis, children: children, weights: Array(repeating: 1, count: children.count))
  }
}

extension PaneNode {
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

  public func contains(_ id: TerminalSession.ID) -> Bool {
    sessionIDs.contains(id)
  }
}
