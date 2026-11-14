import MultishellCore

/// One side of a file whose parse the All changes list keeps: `nil` for
/// Unified's rows or Split's right, `.committed` for Split's left.
struct AllChangesHighlightKey: Hashable {
  let path: String
  let side: DiffSide?
}
