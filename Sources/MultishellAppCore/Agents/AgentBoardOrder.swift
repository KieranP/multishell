/// What comes above what inside a column.
///
/// Most recently entered that state at the top, so the freshest thing in a
/// column is the one read first. The cost is that an arriving card pushes
/// the rest down a place, which is why the last two rules exist: a pane that
/// has never reported has no time to sort on and goes last, and the title
/// then the id break every remaining tie, so a render never reorders cards
/// that have not moved.
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
