import Foundation

/// A `/bin/sh` blocked reading a line, standing in for a running program a
/// test reports the pid of. `marker` is put on its command line.
public final class WaitingShell {
  private let process = Process()
  private let input = Pipe()

  public var pid: Int32 { process.processIdentifier }

  public init(marker: String? = nil) throws {
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "read line" + (marker.map { " # \($0)" } ?? "")]
    process.environment = Scratch.shellEnvironment
    process.standardInput = input
    try process.run()
  }

  /// Its input closed, so the read returns and the shell exits by itself,
  /// waited for here.
  public func finish() throws {
    try input.fileHandleForWriting.close()
    process.waitUntilExit()
  }

  public func terminate() {
    process.terminate()
    process.waitUntilExit()
  }
}
