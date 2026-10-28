import Foundation

/// A `/bin/sh` blocked reading a line, standing in for a running program a
/// test reports the pid of. `marker` is put on its command line, and
/// `backgrounding` runs first as a job the shell kills once its read returns.
public final class WaitingShell {
  private let process = Process()
  private let input = Pipe()
  /// Left by the termination handler. `waitUntilExit` can wait for good on a thread
  /// other than the one that ran the shell, as an async test's defer often is.
  private let exited = DispatchGroup()

  public var pid: Int32 { process.processIdentifier }

  public init(marker: String? = nil, backgrounding job: String? = nil) throws {
    let read = job.map { "\($0) & read line; kill $!" } ?? "read line"
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", read + (marker.map { " # \($0)" } ?? "")]
    process.environment = Scratch.shellEnvironment
    process.standardInput = input
    exited.enter()
    let exited = exited
    process.terminationHandler = { _ in exited.leave() }
    do {
      try process.run()
    } catch {
      // A group freed with an enter unmatched traps.
      exited.leave()
      throw error
    }
  }

  /// Its input closed, so the read returns and the shell exits by itself,
  /// waited for here.
  public func finish() throws {
    try input.fileHandleForWriting.close()
    exited.wait()
  }

  public func terminate() {
    process.terminate()
    exited.wait()
  }
}
