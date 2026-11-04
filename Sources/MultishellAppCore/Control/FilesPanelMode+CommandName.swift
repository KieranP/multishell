import MultishellCore

/// What the command line calls the panel's pages; Changes is `git` there, and the
/// state file keeps `all` and `modified`, `modified` now a change scope.
extension FilesPanelMode: CommandNamed {
  var commandName: String {
    switch self {
    case .ciRuns: "ci"
    case .files: "files"
    case .changes: "git"
    case .pullRequest: "pull-request"
    }
  }
}
