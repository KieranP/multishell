import MultishellProcess

/// What `gh --version` and `gh auth status` say, as one status. Older `gh`
/// writes the login to stderr and says "as"; newer to stdout and "account".
enum GitHubToolReport {
  private static let failureMark = "X "
  /// The first whose `gh api` takes `--allow-escape-sequences`, which a job's log needs.
  private static let minimumVersion = "2.97.0"

  static func status(versionOutput: String, authStatus: ProcessOutput) -> ServiceToolStatus {
    let words = versionOutput.split(whereSeparator: \.isWhitespace)
    guard words.count >= 3, words[0] == "gh", words[1] == "version" else {
      return .unreadable(versionOutput.firstLine)
    }
    let version = String(words[2])
    let text = authStatus.standardOutput + "\n" + authStatus.standardError
    let account = account(in: text)
    // One host's lapsed login fails the whole status, though the others work. A
    // login is asked first: an older gh still reads all but logs, none without one.
    if account == nil, !authStatus.succeeded {
      let failure = GitHubErrorText.failure(from: text)
      return failure == .loggedOut ? .loggedOut : .unreadable(failureReason(in: text))
    }
    if let installed = numbers(of: version), let minimum = numbers(of: minimumVersion),
      installed.lexicographicallyPrecedes(minimum)
    {
      return .unsupportedVersion(version, minimum: minimumVersion)
    }
    return .ready(version: version, account: account)
  }

  /// `2.97.0` and `2.97` as `[2, 97, 0]`, a later part missing or not a number
  /// counting as 0; `nil` for a build from source, `DEV`, whose age cannot be told.
  private static func numbers(of version: String) -> [Int]? {
    let parts = version.split(separator: ".")
    guard let major = parts.first.flatMap({ Int($0) }) else { return nil }
    let later = parts.dropFirst().map { Int($0) ?? 0 }
    return [major] + later + Array(repeating: 0, count: max(0, 2 - later.count))
  }

  /// The line `gh` marks failed, without its mark; the first line is the host's
  /// name when it reports per host.
  private static func failureReason(in text: String) -> String {
    for line in text.split(whereSeparator: \.isNewline) {
      let trimmed = line.drop(while: \.isWhitespace)
      if trimmed.hasPrefix(failureMark) { return String(trimmed.dropFirst(failureMark.count)) }
    }
    return text.firstLine
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
