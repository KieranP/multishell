import MultishellCore

@testable import MultishellAppCore

/// An engine that opens everything and remembers focus and closes.
@MainActor
final class FakeEngine: TerminalSurfaceHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var focused: [TerminalSession.ID] = []
  var closed: [TerminalSession.ID] = []
  /// What was pasted into each session, in order.
  var pasted: [(id: TerminalSession.ID, text: String)] = []
  /// Every search step, in order, whichever pane it was for.
  var searched: [(id: TerminalSession.ID, command: TerminalSearch)] = []
  /// What the registry asked for, command line included.
  var opened: [TerminalSession] = []
  weak var delegate: (any TerminalHostDelegate)?
  /// Every open throws, standing in for a machine out of descriptors.
  var refusesToOpen = false
  func open(_ session: TerminalSession) throws {
    if refusesToOpen { throw OpenRefused() }
    openSessionIDs.insert(session.id)
    opened.append(session)
  }
  func close(_ id: TerminalSession.ID) {
    openSessionIDs.remove(id)
    closed.append(id)
  }
  func focus(_ id: TerminalSession.ID) { focused.append(id) }
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    guard openSessionIDs.contains(id) else { return false }
    pasted.append((id, text))
    return true
  }
  func search(_ command: TerminalSearch, in id: TerminalSession.ID) -> Bool {
    guard openSessionIDs.contains(id) else { return false }
    searched.append((id, command))
    return true
  }
  func view(for id: TerminalSession.ID) -> FakeSurface? { nil }
  func apply(_ theme: Theme, appearance: Appearance) {}
}
