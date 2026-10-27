import Foundation

/// What a failed `circleci` call means. 1.11 prints its error as JSON on stderr,
/// a `code` and a `message`; anything else is read by its first line.
enum CircleCIErrorText {
  private struct Answer: Decodable {
    let code: String?
    let message: String?
  }

  private static let notHostedCodes: Set<String> = ["project.not_found"]
  private static let loggedOutCodePrefixes = ["auth.", "unauthorized", "unauthenticated"]
  /// Its logged-out wording has not been seen, so plain text is matched too.
  private static let loggedOutPhrases = ["auth login", "not authenticated", "unauthorized"]

  static func failure(from text: String) -> ServiceReadFailure {
    guard let answer = try? JSONDecoder().decode(Answer.self, from: Data(text.utf8)) else {
      let folded = text.lowercased()
      return loggedOutPhrases.contains(where: folded.contains)
        ? .loggedOut : .failed(text.firstLine)
    }
    let code = answer.code?.lowercased() ?? ""
    if notHostedCodes.contains(code) { return .notHosted }
    if loggedOutCodePrefixes.contains(where: code.hasPrefix) { return .loggedOut }
    return .failed((answer.message ?? text).firstLine)
  }
}
