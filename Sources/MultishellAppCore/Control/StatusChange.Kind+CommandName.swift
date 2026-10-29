import MultishellGitKit

/// What `files list` calls a row's change.
extension StatusChange.Kind {
  var commandName: String {
    switch self {
    case .added: "added"
    case .deleted: "deleted"
    case .modified: "modified"
    }
  }
}
