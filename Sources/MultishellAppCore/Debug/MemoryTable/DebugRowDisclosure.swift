/// Whether a debug table's row opens to list what is under it, and whether
/// it is open.
public enum DebugRowDisclosure: Sendable, Equatable {
  case collapsed
  case expanded
  case notExpandable

  public var isExpandable: Bool { self != .notExpandable }
}
