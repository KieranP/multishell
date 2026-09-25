import Foundation

/// A shell and the flags that come before the command line it is handed.
public struct ShellInvocation: Equatable, Sendable {
  public let executable: URL
  public let arguments: [String]

  init(executable: URL, arguments: [String]) {
    self.executable = executable
    self.arguments = arguments
  }
}
