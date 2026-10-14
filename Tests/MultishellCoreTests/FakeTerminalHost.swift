import Foundation

@testable import MultishellCore

/// Records what the reconciler asks of a host, in order.
@MainActor
final class FakeTerminalHost: TerminalHost {
  var liveSessionIDs: Set<TerminalSession.ID> = []
  var opened: [TerminalSession] = []
  var log: [String] = []
  /// Sessions whose open throws, as a pty the system would not give.
  var failing: Set<TerminalSession.ID> = []
  weak var delegate: (any TerminalHostDelegate)?

  func open(_ session: TerminalSession) throws {
    if failing.contains(session.id) { throw NSError(domain: "pty", code: 12) }
    liveSessionIDs.insert(session.id)
    opened.append(session)
    log.append("open")
  }

  func close(_ id: TerminalSession.ID) {
    liveSessionIDs.remove(id)
    log.append("close")
  }

  func focus(_ id: TerminalSession.ID) {
    log.append("focus \(id.uuidString.prefix(4))")
  }

  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    log.append("paste \(text)")
    return true
  }

  func type(_ text: String, pressingReturn: Bool, into id: TerminalSession.ID) -> Bool {
    log.append("type \(text)")
    return true
  }

  func press(_ keys: [ControlKey], in id: TerminalSession.ID) -> Bool {
    log.append("press \(keys.map(\.key))")
    return true
  }

  func apply(_ theme: Theme, appearance: Appearance) {}
}
