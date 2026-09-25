import Foundation

@testable import MultishellCore

/// Records what the reconciler asks of a host, in order.
@MainActor
final class RecordingHost: TerminalHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var opened: [TerminalSession] = []
  var log: [String] = []
  /// Sessions whose open throws, as a pty the system would not give.
  var failing: Set<TerminalSession.ID> = []
  weak var delegate: (any TerminalHostDelegate)?

  func open(_ session: TerminalSession) throws {
    if failing.contains(session.id) { throw NSError(domain: "pty", code: 12) }
    openSessionIDs.insert(session.id)
    opened.append(session)
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
