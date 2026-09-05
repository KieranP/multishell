import Foundation

/// The environment a terminal in this app has, captured once.
///
/// An app launched from the Finder has PATH set to the system directories,
/// and every agent people install lives under Homebrew, npm or a version
/// manager. Asking the user's interactive login shell for `env -0` once, off
/// the main thread, gives agent detection and agent tabs the same answer a
/// terminal would. A shell that fails or takes too long yields the process's
/// own environment, and `source` says which happened.
public struct LoginShellEnvironment: Sendable, Equatable {
  public enum Source: Sendable, Equatable {
    case loginShell(URL)
    /// The shell could not be run, timed out, or produced nothing usable.
    case processFallback(reason: String)
  }

  public let variables: [String: String]
  public let source: Source

  public init(variables: [String: String], source: Source) {
    self.variables = variables
    self.source = source
  }

  public var path: String? { variables["PATH"] }

  /// How long the shell gets. Slow rc files exist, but past this the app
  /// would rather run with a poorer PATH than keep the dropdowns empty.
  public static let timeout: Duration = .seconds(8)

  public static func capture(
    runner: ProcessRunner = ProcessRunner(), timeout: Duration = timeout
  ) async -> LoginShellEnvironment {
    let fallback = ProcessInfo.processInfo.environment
    guard let shell = ShellCommand.shell else {
      return LoginShellEnvironment(
        variables: fallback, source: .processFallback(reason: "no shell"))
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    do {
      let output = try await runner.capture(
        shell.executable, shell.arguments + ["env -0"], in: home, timeout: timeout)
      guard output.succeeded else {
        let reason = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        return LoginShellEnvironment(
          variables: fallback,
          source: .processFallback(
            reason: reason.isEmpty ? "exit status \(output.status)" : reason))
      }
      let parsed = parse(nulSeparated: output.standardOutput)
      guard parsed["PATH"] != nil else {
        return LoginShellEnvironment(
          variables: fallback, source: .processFallback(reason: "the shell printed no PATH"))
      }
      return LoginShellEnvironment(variables: parsed, source: .loginShell(shell.executable))
    } catch {
      return LoginShellEnvironment(
        variables: fallback, source: .processFallback(reason: String(describing: error)))
    }
  }

  /// `env -0` output. An rc file that prints a greeting puts it in front of
  /// the first entry; only the text after its last newline is the key.
  static func parse(nulSeparated text: String) -> [String: String] {
    var variables: [String: String] = [:]
    for entry in text.split(separator: "\0", omittingEmptySubsequences: true) {
      guard let equals = entry.firstIndex(of: "=") else { continue }
      var key = String(entry[..<equals])
      if let newline = key.lastIndex(of: "\n") {
        key = String(key[key.index(after: newline)...])
      }
      guard !key.isEmpty, !key.contains(" ") else { continue }
      variables[key] = String(entry[entry.index(after: equals)...])
    }
    return variables
  }
}
