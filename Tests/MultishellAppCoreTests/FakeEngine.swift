import Foundation
import MultishellCore

@testable import MultishellAppCore

/// An engine that remembers focus and closes, and opens everything unless
/// `refusesToOpen` says not to.
@MainActor
final class FakeEngine: TerminalSurfaceHost {
  var liveSessionIDs: Set<TerminalSession.ID> = []
  var focused: [TerminalSession.ID] = []
  var closed: [TerminalSession.ID] = []
  /// What was pasted into each session, in order.
  var pasted: [(id: TerminalSession.ID, text: String)] = []
  /// What was typed into each session, a pressed Return as `\r`.
  var typed: [(id: TerminalSession.ID, text: String)] = []
  var pressed: [(id: TerminalSession.ID, keys: [ControlKey])] = []
  /// Every search step, in order, whichever pane it was for.
  var searched: [(id: TerminalSession.ID, step: TerminalSearch)] = []
  /// What the reconciler asked for, command line included.
  var opened: [TerminalSession] = []
  weak var delegate: (any TerminalHostDelegate)?
  /// Every open throws, standing in for a machine out of descriptors.
  var refusesToOpen = false
  /// What each session's pty is said to be, for placing its processes.
  var processHints: [TerminalSession.ID: TerminalProcessHint] = [:]
  var terminalMemories: [TerminalSession.ID: UInt64] = [:]
  /// What each pane reads as, its screen and its scrollback.
  var screens: [TerminalSession.ID: (screen: String, scrollback: String)] = [:]
  var screenshots: [TerminalSession.ID: Data] = [:]
  var frames: [TerminalSession.ID: CGRect] = [:]

  func open(_ session: TerminalSession) throws {
    if refusesToOpen { throw OpenRefused() }
    liveSessionIDs.insert(session.id)
    opened.append(session)
  }
  func close(_ id: TerminalSession.ID) {
    liveSessionIDs.remove(id)
    closed.append(id)
  }
  func focus(_ id: TerminalSession.ID) { focused.append(id) }
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    guard liveSessionIDs.contains(id) else { return false }
    pasted.append((id, text))
    return true
  }
  func press(_ keys: [ControlKey], in id: TerminalSession.ID) -> Bool {
    guard liveSessionIDs.contains(id) else { return false }
    pressed.append((id, keys))
    return true
  }
  func type(_ text: String, pressingReturn: Bool, into id: TerminalSession.ID) -> Bool {
    guard liveSessionIDs.contains(id) else { return false }
    typed.append((id, text + (pressingReturn ? "\r" : "")))
    return true
  }
  func search(_ step: TerminalSearch, in id: TerminalSession.ID) -> Bool {
    guard liveSessionIDs.contains(id) else { return false }
    searched.append((id, step))
    return true
  }
  func view(for id: TerminalSession.ID) -> FakeSurface? { nil }
  func processHint(of id: TerminalSession.ID) -> TerminalProcessHint? { processHints[id] }
  func terminalMemory(of id: TerminalSession.ID) -> UInt64? { terminalMemories[id] }
  func text(of id: TerminalSession.ID, includingScrollback: Bool) -> String? {
    guard liveSessionIDs.contains(id) else { return nil }
    let text = screens[id] ?? ("", "")
    return includingScrollback ? text.scrollback + text.screen : text.screen
  }
  func screenshot(of id: TerminalSession.ID) -> Data? { screenshots[id] }
  func frame(of id: TerminalSession.ID) -> CGRect? { frames[id] }
  func apply(_ theme: Theme, appearance: Appearance) {}
}
