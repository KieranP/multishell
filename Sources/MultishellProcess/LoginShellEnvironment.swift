import Foundation

/// The environment a terminal here has, from one `env -0` through the login
/// shell: from the Finder, PATH is the system directories alone.
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

  /// `shellPath`, `home` and `inherited` stand in for `$SHELL`, the home and
  /// what the app was started with, so a test runs a real shell of its own.
  public static func capture(
    runner: ProcessRunner = ProcessRunner(), timeout: Duration = timeout,
    shellPath: String? = nil, home: URL? = nil, inherited: [String: String] = [:]
  ) async -> LoginShellEnvironment {
    let fallback = ProcessInfo.processInfo.environment
    guard let shell = ShellCommand.shell(preferring: shellPath) else {
      return LoginShellEnvironment(
        variables: fallback, source: .processFallback(reason: "no shell"))
    }
    let directory = home ?? FileManager.default.homeDirectoryForCurrentUser
    let environment = ShellCommand.historyless(
      inherited.merging(home.map { ["HOME": $0.path, "ZDOTDIR": $0.path] } ?? [:]) { $1 })
    do {
      let output = try await runner.capture(
        shell.executable, shell.arguments + ["printf '\\n%s\\n' \(startMarker); env -0"],
        in: directory, environment: environment,
        timeout: timeout)
      guard output.succeeded else {
        return LoginShellEnvironment(
          variables: fallback, source: .processFallback(reason: failureReason(output)))
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

  /// A timed-out shell's status is only the SIGHUP that ended it.
  private static func failureReason(_ output: ProcessOutput) -> String {
    if case .timedOut(let after) = output.stop { return "timed out after \(after)" }
    let stderr = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
    return stderr.isEmpty ? "exit status \(output.status)" : stderr
  }

  /// Printed on a line of its own before `env -0`, after any greeting the rc
  /// files wrote: a greeting shaped like `KEY=` was taken for a variable.
  static let startMarker = "__multishell_env__"

  /// `env -0` output, from the line after the marker. Without one, an entry
  /// begins at the first line reading `KEY=`, which a greeting can fool.
  static func parse(nulSeparated text: String) -> [String: String] {
    let marked = text.range(of: "\n\(startMarker)\n").map { text[$0.upperBound...] }
    var variables: [String: String] = [:]
    for whole in (marked ?? text[...]).split(separator: "\0", omittingEmptySubsequences: true) {
      guard let entry = marked == nil ? entryAfterGreeting(whole) : whole,
        let equals = entry.firstIndex(of: "=")
      else {
        continue
      }
      variables[String(entry[..<equals])] = String(entry[entry.index(after: equals)...])
    }
    return variables
  }

  /// A greeting with no final newline is not told from the key it runs into.
  private static func entryAfterGreeting(_ entry: Substring) -> Substring? {
    var start = entry.startIndex
    while start < entry.endIndex {
      let rest = entry[start...]
      if let equals = rest.firstIndex(of: "=") {
        let key = rest[..<equals]
        if !key.isEmpty, !key.contains(where: { $0 == " " || $0 == "\n" }) { return rest }
      }
      guard let newline = rest.firstIndex(of: "\n") else { return nil }
      start = rest.index(after: newline)
    }
    return nil
  }
}
