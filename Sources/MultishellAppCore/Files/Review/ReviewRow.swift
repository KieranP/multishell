import MultishellCore

/// One comment as Review lists it.
public struct ReviewRow: Identifiable, Equatable, Sendable {
  public let id: ReviewComment.ID
  public let lineLabel: String
  /// "(Branch)" for removed lines written under the scope not shown, whose
  /// card the file tab leaves out until that scope is chosen again.
  public let scopeNote: String?
  public let chip: ReviewChip
  public let text: String
  public let isSelected: Bool
}
