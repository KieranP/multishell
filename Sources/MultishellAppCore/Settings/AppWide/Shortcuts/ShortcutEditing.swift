import MultishellCore

/// A Shortcuts row part way through a change: recording keys, saying why the
/// last were refused, or asking before it takes keys another command holds.
public struct ShortcutEditing: Hashable, Sendable {
  public enum Step: Hashable, Sendable {
    case recording(ShortcutRefusal?)
    case confirming(KeyCombination, takenFrom: ShortcutCommand)
  }

  let command: ShortcutCommand
  let step: Step
}
