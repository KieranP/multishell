import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// Started at the prompt, so it shares the shell's process group: a Ctrl-C
  /// or Ctrl-Z there reaches it too, and a hang-up comes before the last lines.
  private static let relayIgnores = [SIGHUP, SIGINT, SIGQUIT, SIGTSTP, SIGTTIN, SIGTTOU, SIGPIPE]

  /// Ends at EOF or when the shell exits, as a child it started may hold the
  /// pipe open past it. A line it cannot read is dropped: that child could write.
  static func relay(environment: [String: String], input: FileHandle, shellPID: Int32?) {
    for number in relayIgnores { _ = signal(number, SIG_IGN) }
    let watch = shellPID.flatMap { InputOrExitWatch(descriptor: input.fileDescriptor, pid: $0) }
    var pending = Data()
    func relayLines() {
      while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
        relayLine(String(decoding: pending[..<newline], as: UTF8.self), environment: environment)
        pending.removeSubrange(...newline)
      }
    }
    while true {
      if let watch, watch.next() == .exited {
        pending.append(watch.drain())
        relayLines()
        return
      }
      let chunk = input.availableData
      guard !chunk.isEmpty else { return }
      pending.append(chunk)
      relayLines()
    }
  }

  private static func relayLine(_ line: String, environment: [String: String]) {
    let fields = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    guard fields.count == 3 else { return }
    switch fields[0] {
    case "command-started":
      reportShellState(
        SessionState.running, environment: environment, pid: Int32(fields[1]),
        command: fields[2])
    case "command-finished":
      reportShellState(
        SessionState.finished(exitCode: Int32(fields[1])), environment: environment,
        duration: Double(fields[2]))
    default:
      return
    }
  }
}
