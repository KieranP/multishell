import Foundation

/// What comes above what inside a column: most recently entered at the top,
/// then title and id, so a render never reorders cards that have not moved.
enum AgentBoardOrder {
  static func precedes(_ lhs: AgentBoardCard, _ rhs: AgentBoardCard) -> Bool {
    if let bySince = DateOrder.precedes(lhs.since, rhs.since, newestFirst: true) { return bySince }
    if lhs.title != rhs.title { return lhs.title < rhs.title }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}
