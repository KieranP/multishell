import MultishellCore

/// An action row's keys being recorded on the Actions page, and why the last
/// keys pressed were not taken.
public struct ActionKeysRecording: Hashable, Sendable {
  public enum Refusal: Hashable, Sendable {
    case refused(ShortcutRefusal)
    case heldBy(KeyCombination, ShortcutCommand)
  }

  let projectID: Project.ID
  let actionName: String
  public let refusal: Refusal?
}
