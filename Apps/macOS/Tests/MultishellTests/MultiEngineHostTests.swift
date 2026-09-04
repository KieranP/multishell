import AppKit
import MultishellCore
import Testing

@testable import Multishell

/// An engine that records what it was asked and can be made to fail.
@MainActor
private final class RecordingEngine: TerminalSurfaceHost {
  let name: TerminalEngine
  var openSessionIDs: Set<TerminalSession.ID> = []
  var log: [String] = []
  var failNextOpen = false
  var appliedThemes: [Theme.ID] = []
  weak var delegate: (any TerminalHostDelegate)?

  init(_ name: TerminalEngine) { self.name = name }

  func open(_ session: TerminalSession) throws {
    if failNextOpen {
      failNextOpen = false
      throw NSError(domain: "test", code: 1)
    }
    openSessionIDs.insert(session.id)
    log.append("open")
  }

  func close(_ id: TerminalSession.ID) {
    openSessionIDs.remove(id)
    log.append("close")
  }

  func focus(_ id: TerminalSession.ID) { log.append("focus") }
  func view(for id: TerminalSession.ID) -> NSView? { openSessionIDs.contains(id) ? NSView() : nil }
  func apply(_ theme: Theme, appearance: Appearance) { appliedThemes.append(theme.id) }
}

@MainActor
private final class RecordingDelegate: TerminalHostDelegate {
  var events: [String] = []
  func terminalHost(_ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String) {
    events.append("retitle \(title)")
  }
  func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID, code: Int32) {
    events.append("exit \(code)")
  }
  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID) {
    events.append("activity")
  }
  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID) {
    events.append("focus")
  }
}

@Suite @MainActor
struct MultiEngineHostTests {
  private var engines: [TerminalEngine: RecordingEngine] = [:]

  private func makeHost(
    starting engine: TerminalEngine = .ghostty
  ) -> (MultiEngineHost, (TerminalEngine) -> RecordingEngine) {
    let store = EngineStore()
    let host = MultiEngineHost(engine: engine) { store.engine(for: $0) }
    return (host, store.engine(for:))
  }

  private func session(_ dir: String = "/tmp") -> TerminalSession {
    TerminalSession(worktreeID: "/w", workingDirectory: URL(fileURLWithPath: dir), title: "t")
  }

  @Test func aSessionStaysWithTheEngineThatOpenedIt() throws {
    let (host, engine) = makeHost()
    let first = session()
    try host.open(first)
    host.engine = .swiftTerm
    let second = session()
    try host.open(second)

    #expect(engine(.ghostty).openSessionIDs == [first.id])
    #expect(engine(.swiftTerm).openSessionIDs == [second.id])
    #expect(host.openSessionIDs == [first.id, second.id])

    host.close(first.id)
    host.focus(second.id)
    #expect(engine(.ghostty).log == ["open", "close"])
    #expect(engine(.swiftTerm).log == ["open", "focus"])
    #expect(host.view(for: second.id) != nil)
    #expect(host.view(for: first.id) == nil)
  }

  @Test func enginesAreCreatedLazilyAndStyledOnCreation() throws {
    let store = EngineStore()
    let host = MultiEngineHost(engine: .ghostty) { store.engine(for: $0) }
    host.apply(.multishellLight, appearance: Appearance())
    #expect(store.created.isEmpty, "nothing until a session needs it")

    try host.open(session())
    #expect(store.created == [.ghostty])
    #expect(store.engine(for: .ghostty).appliedThemes == [Theme.multishellLight.id])

    host.apply(.multishellDark, appearance: Appearance())
    #expect(store.engine(for: .ghostty).appliedThemes.last == Theme.multishellDark.id)
    #expect(store.created == [.ghostty], "applying a theme does not create the other engine")
  }

  @Test func exitKeepsOwnershipSoTheFollowUpCloseReachesTheEngine() throws {
    let (host, engine) = makeHost()
    let delegate = RecordingDelegate()
    host.delegate = delegate
    let s = session()
    try host.open(s)

    // The engine reports the process ended; the registry answers with close.
    engine(.ghostty).delegate?.terminalHost(engine(.ghostty), didExit: s.id, code: 0)
    host.close(s.id)

    #expect(delegate.events == ["exit 0"])
    #expect(engine(.ghostty).log == ["open", "close"])
    #expect(host.openSessionIDs.isEmpty)
  }

  @Test func engineEventsAreForwardedAsTheCompositeHost() throws {
    let (host, engine) = makeHost()
    let delegate = RecordingDelegate()
    host.delegate = delegate
    let s = session()
    try host.open(s)
    let child = engine(.ghostty)

    child.delegate?.terminalHost(child, didRetitle: s.id, to: "vim")
    child.delegate?.terminalHost(child, didSeeActivityIn: s.id)
    child.delegate?.terminalHost(child, didFocus: s.id)

    #expect(delegate.events == ["retitle vim", "activity", "focus"])
  }

  @Test func aFailedOpenLeavesNoOwnership() {
    let (host, engine) = makeHost()
    engine(.ghostty).failNextOpen = true
    let s = session()

    #expect(throws: (any Error).self) { try host.open(s) }
    #expect(host.openSessionIDs.isEmpty)
    #expect(host.view(for: s.id) == nil)
  }
}

/// Hands out one recording engine per kind and remembers creation order.
@MainActor
private final class EngineStore {
  private var engines: [TerminalEngine: RecordingEngine] = [:]
  private(set) var created: [TerminalEngine] = []

  func engine(for kind: TerminalEngine) -> RecordingEngine {
    if let existing = engines[kind] { return existing }
    let engine = RecordingEngine(kind)
    engines[kind] = engine
    created.append(kind)
    return engine
  }
}
