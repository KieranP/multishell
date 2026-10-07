import Foundation
import MultishellProcess

extension Helper {
  /// Started at the prompt, so it shares the shell's process group: a Ctrl-C
  /// or Ctrl-Z there reaches it too, and a hang-up comes before the last lines.
  private static let relayIgnoredSignals = [
    SIGHUP, SIGINT, SIGQUIT, SIGTSTP, SIGTTIN, SIGTTOU, SIGPIPE,
  ]

  static func relay(
    _ arguments: ArraySlice<String>, environment: [String: String], input: FileHandle
  ) throws {
    let options = try CommandOptions(arguments, valued: ["pid"])
    relay(environment: environment, input: input, shellPID: options.int32("pid"))
  }

  /// Ends at EOF or when the shell exits, as a child it started may hold the
  /// pipe open past it. A line it cannot read is dropped: that child could write.
  private static func relay(environment: [String: String], input: FileHandle, shellPID: Int32?) {
    for number in relayIgnoredSignals { _ = signal(number, SIG_IGN) }
    let watch = shellPID.flatMap { InputOrExitWatch(descriptor: input.fileDescriptor, pid: $0) }
    var pending = LineBuffer()
    func relayLines(_ chunk: Data) {
      for line in pending.append(chunk) { relayLine(line, environment: environment) }
    }
    while true {
      if let watch, watch.next() == .exited {
        relayLines(watch.drain())
        return
      }
      let chunk = input.availableData
      guard !chunk.isEmpty else { return }
      relayLines(chunk)
    }
  }

  private static func relayLine(_ line: String, environment: [String: String]) {
    let fields = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    guard fields.count == 3 else { return }
    switch fields[0] {
    case "command-started":
      reportCommandStarted(environment: environment, shellPID: Int32(fields[1]), command: fields[2])
    case "command-finished":
      reportCommandFinished(
        environment: environment, exitCode: Int32(fields[1]), duration: Double(fields[2]))
    default:
      return
    }
  }
}
