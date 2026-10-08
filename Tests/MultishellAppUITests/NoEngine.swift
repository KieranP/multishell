import AppKit
import MultishellAppCore
import MultishellCore

@MainActor
final class NoEngine: TerminalSurfaceHost {
  var liveSessionIDs: Set<TerminalSession.ID> = []
  weak var delegate: (any TerminalHostDelegate)?
  func open(_ session: TerminalSession) throws {}
  func close(_ id: TerminalSession.ID) {}
  func focus(_ id: TerminalSession.ID) {}
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool { false }
  func view(for id: TerminalSession.ID) -> NSView? { nil }
  func processHint(of id: TerminalSession.ID) -> TerminalProcessHint? { nil }
  func terminalMemory(of id: TerminalSession.ID) -> UInt64? { nil }
  func apply(_ theme: Theme, appearance: Appearance) {}
}
