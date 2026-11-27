/// The line under an action row's keys: why the keys pressed were not taken,
/// or what a pane gives up to the keys set.
public enum ActionKeysNote: Hashable, Sendable {
  case refusal(ActionKeysRecording.Refusal)
  case warning(ShortcutWarning)
}
