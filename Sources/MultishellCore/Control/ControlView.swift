/// What `multishell ui show` and `ui hide` open and close, by the word the
/// command line spells it with.
public enum ControlView: String, Codable, CaseIterable, Sendable {
  case agentBoard = "board"
  /// The board's Show all terminals, not only agents' panes.
  case allTerminals = "all-terminals"
  case projectSettings = "project-settings"
  case settings
}
