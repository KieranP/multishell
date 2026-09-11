/// What comes above what inside a column: most recently entered at the top,
/// then title and id, so a render never reorders cards that have not moved.
public enum AgentBoardOrder {
  public static func precedes(_ lhs: AgentBoardCard, _ rhs: AgentBoardCard) -> Bool {
    switch (lhs.since, rhs.since) {
    case (let left?, let right?) where left != right: return left > right
    case (nil, .some): return false
    case (.some, nil): return true
    default: break
    }
    if lhs.title != rhs.title { return lhs.title < rhs.title }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}
