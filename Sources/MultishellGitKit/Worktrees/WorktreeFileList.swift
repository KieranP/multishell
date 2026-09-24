import MultishellCore

/// A list as a create will place it: the paths in force, and whether the
/// repository listed them, which is what is held to the checkout (settings.md).
public struct WorktreeFileList: Sendable {
  public let placement: WorktreePlacement
  let paths: String
  let heldToRepository: Bool

  public init(placement: WorktreePlacement, paths: String, heldToRepository: Bool) {
    self.placement = placement
    self.paths = paths
    self.heldToRepository = heldToRepository
  }
}
