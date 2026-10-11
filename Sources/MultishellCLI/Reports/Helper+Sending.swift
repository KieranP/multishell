import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  /// Under the five seconds an agent gives a hook, and short of a prompt
  /// waiting on an app that has stopped reading.
  private static let reportTimeout: Duration = .seconds(2)

  static func send(_ report: SessionStateReport, environment: [String: String]) throws {
    let socket =
      environment[SessionEnvironment.socketVariable].map { URL(fileURLWithPath: $0) }
      ?? Paths.socketFile
    try UnixSocketClient.send(try report.encodedLine(), to: socket, timeout: reportTimeout)
  }
}
