import Foundation

@testable import MultishellCore

/// Records what the registry asks of a host, in order.
@MainActor
final class RecordingHost: TerminalHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var log: [String] = []
  weak var delegate: (any TerminalHostDelegate)?

  func open(_ session: TerminalSession) throws {
    openSessionIDs.insert(session.id)
    log.append("open")
  }

  func close(_ id: TerminalSession.ID) {
    openSessionIDs.remove(id)
    log.append("close")
  }

  func focus(_ id: TerminalSession.ID) {
    log.append("focus \(id.uuidString.prefix(4))")
  }

  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    log.append("paste \(text)")
    return true
  }

  func apply(_ theme: Theme, appearance: Appearance) {}
}
