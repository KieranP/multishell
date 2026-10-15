import AppKit
import Foundation
import MultishellAppCore
import MultishellCore

@MainActor
final class NullEngine: TerminalSurfaceHost {
  var liveSessionIDs: Set<TerminalSession.ID> = []
  weak var delegate: (any TerminalHostDelegate)?
  func open(_ session: TerminalSession) throws {}
  func close(_ id: TerminalSession.ID) {}
  func focus(_ id: TerminalSession.ID) {}
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool { false }
  func type(_ text: String, pressingReturn: Bool, into id: TerminalSession.ID) -> Bool { false }
  func press(_ keys: [ControlKey], in id: TerminalSession.ID) -> Bool { false }
  func view(for id: TerminalSession.ID) -> NSView? { nil }
  func processHint(of id: TerminalSession.ID) -> TerminalProcessHint? { nil }
  func terminalMemory(of id: TerminalSession.ID) -> UInt64? { nil }
  func text(of id: TerminalSession.ID, includingScrollback: Bool) -> String? { nil }
  func selectionText(of id: TerminalSession.ID) -> String? { nil }
  func screenshot(of id: TerminalSession.ID) -> Data? { nil }
  func frame(of id: TerminalSession.ID) -> CGRect? { nil }
  func apply(_ theme: Theme, appearance: Appearance) {}
}
