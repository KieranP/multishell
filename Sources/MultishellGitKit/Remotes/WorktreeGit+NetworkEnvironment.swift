extension WorktreeGit {
  /// A call to a remote fails rather than waits on a credentials prompt that
  /// no terminal shows.
  static let networkEnvironment = ["GIT_TERMINAL_PROMPT": "0"]
}
