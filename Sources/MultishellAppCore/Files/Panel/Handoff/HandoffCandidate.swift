/// An item a page lists as sendable, and whether its checkbox starts checked:
/// a failing optional check starts unchecked, everything else checked.
public struct HandoffCandidate: Hashable, Sendable {
  public let id: HandoffItemID
  let startsChecked: Bool

  init(_ id: HandoffItemID, startsChecked: Bool = true) {
    self.id = id
    self.startsChecked = startsChecked
  }
}
