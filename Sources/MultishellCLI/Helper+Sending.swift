import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  static func send(_ report: SessionStateReport, environment: [String: String]) throws {
    let socket =
      environment[SessionEnvironment.socketKey].map { URL(fileURLWithPath: $0) }
      ?? Paths.socketFile
    try UnixSocketClient.send(try report.encodedLine(), to: socket)
  }
}
