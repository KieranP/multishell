/// One job of a CI workflow, as the popover lists it.
public struct CIJob: Hashable, Sendable {
  /// The provider's own id, which opens the job; `nil` where it gave none.
  public let id: String?
  public let name: String
  public let status: CIRunStatus
}
