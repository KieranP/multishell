import MultishellProcess

/// What `circleci version` and `circleci auth me` say, as one status. The
/// run commands came with 1.0; the 0.1 CLI before it has none of them.
enum CircleCIToolReport {
  private static let firstMajorWithRuns = 1

  static func status(versionOutput: String, authMe: ProcessOutput) -> ServiceToolStatus {
    guard let (version, major) = version(in: versionOutput) else {
      return .unreadable(versionOutput.firstLine)
    }
    guard major >= firstMajorWithRuns else { return .unsupportedVersion(version) }
    guard authMe.succeeded else {
      let text = authMe.standardOutput + "\n" + authMe.standardError
      switch CircleCIErrorText.failure(from: text) {
      case .loggedOut: return .loggedOut
      case .failed(let said): return .unreadable(said)
      case .notHosted: return .unreadable(text.firstLine)
      }
    }
    return .ready(version: version, account: nil)
  }

  /// `false` only for a version known to lack the run commands: an answer
  /// that cannot be read is no verdict, and the reads say what is wrong.
  static func canRead(versionOutput: String) -> Bool {
    version(in: versionOutput).map { $0.major >= firstMajorWithRuns } ?? true
  }

  /// `circleci 1.11.0 (cee106974671)`; the 0.1 CLI printed the bare number.
  private static func version(in output: String) -> (text: String, major: Int)? {
    let words = output.split(whereSeparator: \.isWhitespace)
    guard let version = words.first(where: { $0.first?.isNumber == true }).map(String.init),
      let major = version.split(separator: ".").first.flatMap({ Int($0) })
    else { return nil }
    return (version, major)
  }
}
