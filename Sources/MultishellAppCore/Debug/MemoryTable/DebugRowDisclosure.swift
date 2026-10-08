/// Whether a debug table's row opens to list what is under it, and whether
/// it is open.
public enum DebugRowDisclosure: Sendable, Equatable {
  case notExpandable
  case collapsed
  case expanded

  public var isExpandable: Bool { self != .notExpandable }
}
