import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

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
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    log.append("paste \(text)")
    return true
  }
  func view(for id: TerminalSession.ID) -> FakeSurface? {
    openSessionIDs.contains(id) ? FakeSurface() : nil
  }
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
  func terminalHost(
    _ host: any TerminalHost, didFinishCommandIn id: TerminalSession.ID, exitCode: Int32?
  ) {
    events.append("finished \(exitCode ?? -1)")
  }
}

@Suite @MainActor
struct MultiEngineHostTests {
  private var engines: [TerminalEngine: RecordingEngine] = [:]

  private func makeHost(
    starting engine: TerminalEngine = .ghostty
  ) -> (MultiEngineHost<FakeSurface>, (TerminalEngine) -> RecordingEngine) {
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

    host.paste("@a.swift ", into: second.id)
    host.close(first.id)
    host.focus(second.id)
    #expect(engine(.ghostty).log == ["open", "close"])
    #expect(engine(.swiftTerm).log == ["open", "paste @a.swift ", "focus"])
    #expect(host.view(for: second.id) != nil)
    #expect(host.view(for: first.id) == nil)
    #expect(!host.paste("x", into: first.id), "a session no engine owns takes no text")
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
    child.delegate?.terminalHost(child, didFinishCommandIn: s.id, exitCode: 3)

    #expect(delegate.events == ["retitle vim", "activity", "focus", "finished 3"])
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

/// Random opens, closes, focuses and engine switches. Whatever the order,
/// the composite must report exactly the union of its engines, know the
/// owner of every open session and of none that is closed, and never hand a
/// view for a session it does not have.
@Suite @MainActor
struct MultiEngineHostInvariantTests {
  private struct Generator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
      state ^= state << 13
      state ^= state >> 7
      state ^= state << 17
      return state
    }
  }

  @Test(arguments: [2, 5, 11, 23, 47] as [UInt64])
  func routingStaysConsistent(seed: UInt64) throws {
    var rng = Generator(state: seed)
    let store = EngineStore()
    let host = MultiEngineHost(engine: .ghostty) { store.engine(for: $0) }
    var sessions: [TerminalSession] = []

    for step in 0..<200 {
      switch Int.random(in: 0..<6, using: &rng) {
      case 0, 1:
        let session = TerminalSession(
          worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/tmp"), title: "t")
        if Bool.random(using: &rng) { store.engine(for: host.engine).failNextOpen = true }
        sessions.append(session)
        try? host.open(session)
      case 2:
        if let session = sessions.randomElement(using: &rng) { host.close(session.id) }
      case 3:
        if let session = sessions.randomElement(using: &rng) { host.focus(session.id) }
      case 4:
        host.engine = host.engine == .ghostty ? .swiftTerm : .ghostty
      default:
        host.apply(
          Bool.random(using: &rng) ? .multishellDark : .multishellLight, appearance: Appearance())
      }

      let engines = TerminalEngine.allCases.compactMap {
        store.created.contains($0) ? store.engine(for: $0) : nil
      }
      let union = engines.reduce(into: Set<TerminalSession.ID>()) {
        $0.formUnion($1.openSessionIDs)
      }
      #expect(host.openSessionIDs == union, "seed \(seed) step \(step): not the union")
      for session in sessions {
        let open = union.contains(session.id)
        #expect(
          (host.view(for: session.id) != nil) == open,
          "seed \(seed) step \(step): view for a closed session")
      }
      let overlap = engines.map(\.openSessionIDs).reduce(0) { $0 + $1.count }
      #expect(overlap == union.count, "seed \(seed) step \(step): a session in two engines")
    }
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
