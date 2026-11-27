import MultishellServices

extension PullRequest {
  /// Whether its head is in one of the repositories a remote pushes to, so a
  /// fork's branch of the same name is not taken for this one.
  func isHeaded(inAnyOf repositories: [RemoteRepository]) -> Bool {
    repositories.contains(where: headRepository.isSame(as:))
  }

  /// The same, any head counting where the remote's URL names no repository.
  func isHeadedWhereKnown(inAnyOf repositories: [RemoteRepository]) -> Bool {
    repositories.isEmpty || isHeaded(inAnyOf: repositories)
  }
}
