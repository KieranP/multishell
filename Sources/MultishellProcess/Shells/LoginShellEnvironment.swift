import Foundation

/// The environment a terminal here has, from one `env -0` through the login
/// shell: from the Finder, PATH is the system directories alone.
public struct LoginShellEnvironment: Sendable, Equatable {
  public enum Source: Sendable, Equatable {
    case loginShell(URL)
    /// The shell could not be run, timed out, or produced nothing usable.
    case processFallback(reason: String)
  }

  let variables: [String: String]
  public let source: Source

  public var path: String? { variables["PATH"] }

  /// How long the shell gets. Slow rc files exist, but past this the app
  /// would rather run with a poorer PATH than keep the dropdowns empty.
  public static let timeout: Duration = .seconds(8)

  /// `home` and `extraEnvironment` are a test's, so it runs a real shell of its
  /// own; the extra variables are laid over the app's, adding or replacing only.
  public static func capture(
    timeout: Duration = timeout, shellPath: String, home: URL? = nil,
    extraEnvironment: [String: String] = [:]
  ) async -> LoginShellEnvironment {
    let fallback = ProcessInfo.processInfo.environment
    let shell = ShellInvocation.forCommandLine(inShellAt: shellPath)
    let directory = home ?? FileManager.default.homeDirectoryForCurrentUser
    let environment = ShellInvocation.historyless(
      extraEnvironment.merging(home.map { ["HOME": $0.path, "ZDOTDIR": $0.path] } ?? [:]) { $1 })
    do {
      let output = try await ProcessRunner().capture(
        shell.executable,
        shell.arguments + ["printf '\\n%s\\n' \(EnvironmentDumpParser.startMarker); env -0"],
        in: directory, environment: environment,
        timeout: timeout)
      guard output.succeeded else {
        return LoginShellEnvironment(
          variables: fallback, source: .processFallback(reason: failureReason(output)))
      }
      let parsed = EnvironmentDumpParser.parse(nulSeparated: output.standardOutput)
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
    if case .timedOut(let after) = output.stopReason { return "timed out after \(after)" }
    let stderr = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
    return stderr.isEmpty ? "exit status \(output.status)" : stderr
  }
}
