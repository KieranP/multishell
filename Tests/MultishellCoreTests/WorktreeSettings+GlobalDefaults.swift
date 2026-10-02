@testable import MultishellCore

extension WorktreeSettings {
  /// A global with both a directory and a prefix, for a project to layer over.
  static let globalDefaults = WorktreeSettings(
    worktreeDirectory: "/global/trees", branchPrefix: "team/")
}
