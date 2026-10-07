/// Whether a debug table's line opens to list what is under it, and whether
/// it is open.
public enum DebugLineDisclosure: Sendable, Equatable {
  case notExpandable
  case collapsed
  case expanded

  public var isExpandable: Bool { self != .notExpandable }
}
