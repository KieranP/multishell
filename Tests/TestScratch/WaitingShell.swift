import Foundation

/// A `/bin/sh` blocked reading a line, standing in for a running program a
/// test reports the pid of. `marker` is put on its command line.
public final class WaitingShell {
  private let process = Process()
  private let input = Pipe()

  public init(marker: String? = nil) throws {
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "read line" + (marker.map { " # \($0)" } ?? "")]
    process.standardInput = input
    try process.run()
  }

  public var pid: Int32 { process.processIdentifier }

  /// Its input closed, so the read returns and the shell exits by itself,
  /// waited for here.
  public func finish() throws {
    try input.fileHandleForWriting.close()
    process.waitUntilExit()
  }

  public func end() {
    process.terminate()
    process.waitUntilExit()
  }
}
