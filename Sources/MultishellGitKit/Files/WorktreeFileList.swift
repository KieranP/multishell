/// A list as a create will place it: the paths in force, and whether the
/// repository listed them, which is what is held to the checkout (settings.md).
public struct WorktreeFileList: Sendable {
  public let placement: WorktreeFilePlacement
  let listText: String
  let heldToRepository: Bool

  public init(placement: WorktreeFilePlacement, listText: String, heldToRepository: Bool) {
    self.placement = placement
    self.listText = listText
    self.heldToRepository = heldToRepository
  }
}
