extension PaneNode {
  /// The pane beside `id` in its own split, which grows into its room when it
  /// closes: the one before it, else the one after. `nil` where it has none.
  func neighbour(of id: TerminalSession.ID) -> TerminalSession.ID? {
    guard case .split(_, let children, _) = self,
      let index = children.firstIndex(where: { $0.contains(id) })
    else { return nil }
    guard children[index] == .terminal(id) else { return children[index].neighbour(of: id) }
    if index > 0 { return children[index - 1].sessionIDs.last }
    return children.dropFirst().first?.sessionIDs.first
  }
}
