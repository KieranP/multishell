import MultishellCore

/// What the command line calls the panel's lists: Files and Git, as drawn, where
/// the state file keeps `all` and `modified`, `modified` now a change scope.
extension FilesPanelMode {
  var commandName: String {
    switch self {
    case .files: "files"
    case .git: "git"
    }
  }

  init?(commandName: String) {
    switch commandName {
    case "files": self = .files
    case "git": self = .git
    default: return nil
    }
  }
}
