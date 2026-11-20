import MultishellCore

/// One side of a file whose parse the All changes list keeps: `nil` for
/// Unified's rows or Split's right, `.committed` for Split's left.
public struct AllChangesHighlightKey: Hashable {
  public let path: String
  public let side: DiffSide?

  public init(path: String, side: DiffSide?) {
    self.path = path
    self.side = side
  }
}
