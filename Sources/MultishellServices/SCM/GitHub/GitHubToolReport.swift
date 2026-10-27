import MultishellProcess

/// What `gh --version` and `gh auth status` say, as one status. Older `gh`
/// writes the login to stderr and says "as"; newer to stdout and "account".
enum GitHubToolReport {
  static func status(versionOutput: String, authStatus: ProcessOutput) -> ServiceToolStatus {
    let words = versionOutput.split(whereSeparator: \.isWhitespace)
    guard words.count >= 3, words[0] == "gh", words[1] == "version" else {
      return .unreadable(versionOutput.firstLine)
    }
    let version = String(words[2])
    let text = authStatus.standardOutput + "\n" + authStatus.standardError
    // One host's lapsed login fails the whole status, though the others work.
    if let account = account(in: text) { return .ready(version: version, account: account) }
    guard authStatus.succeeded else {
      let failure = GitHubErrorText.failure(from: text)
      return failure == .loggedOut ? .loggedOut : .unreadable(text.firstLine)
    }
    return .ready(version: version, account: nil)
  }

  /// The first login named, `KieranP` of "Logged in to github.com account
  /// KieranP (keyring)".
  private static func account(in text: String) -> String? {
    for line in text.split(whereSeparator: \.isNewline) {
      let words = line.split(whereSeparator: \.isWhitespace)
      guard let logged = words.firstIndex(of: "Logged"), words.count > logged + 5,
        words[logged + 1] == "in", words[logged + 2] == "to",
        ["account", "as"].contains(words[logged + 4])
      else { continue }
      return String(words[logged + 5])
    }
    return nil
  }
}
