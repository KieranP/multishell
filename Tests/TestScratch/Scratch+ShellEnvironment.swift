import Foundation

@testable import MultishellProcess

extension Scratch {
  /// An exported `HISTFILE` had an interactive bash append each test's commands to the
  /// developer's own. Empty, not absent, as `ProcessRunner` merges it over its own environment.
  public static var shellEnvironment: [String: String] {
    ShellInvocation.historyless(ProcessInfo.processInfo.environment)
  }

  /// A shell's whole environment: the system PATH, no history file, and a
  /// scratch home, so nothing of the developer's is read or written.
  public static func bareShellEnvironment(home: URL) -> [String: String] {
    ["PATH": "/usr/bin:/bin", "HISTFILE": "", "HOME": home.path]
  }
}
