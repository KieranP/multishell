/// What a failed `gh` call means, from what it printed: the wording is `gh`'s
/// own, so an unrecognised message is passed on as said.
enum GitHubErrorText {
  /// `gh` resolves the repository from the remotes before any network call.
  private static let notHostedPhrases = [
    "none of the git remotes configured for this repository point to a known github host",
    "no git remotes found",
    "not a git repository",
  ]
  private static let loggedOutPhrases = [
    "gh auth login", "not logged in", "authentication required",
  ]

  static func failure(from text: String) -> ServiceReadFailure {
    let folded = text.lowercased()
    if notHostedPhrases.contains(where: folded.contains) { return .notHosted }
    if loggedOutPhrases.contains(where: folded.contains) { return .loggedOut }
    return .failed(text.firstLine)
  }
}
