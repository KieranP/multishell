import AppKit
import MultishellCore

/// One host that fronts both engines.
///
/// A session belongs to the engine that opened it for its whole life, so
/// changing the engine in Settings affects the next tab, not the shells that
/// are already running. Engines are created on first use; a user who never
/// picks SwiftTerm never pays for it.
@MainActor
final class MultiEngineHost: TerminalSurfaceHost {
  /// Engine for sessions opened from now on.
  var engine: TerminalEngine

  weak var delegate: (any TerminalHostDelegate)?

  private var hosts: [TerminalEngine: any TerminalSurfaceHost] = [:]
  private var owner: [TerminalSession.ID: TerminalEngine] = [:]
  private var theme: Theme?
  private var appearance: Appearance?
  private let makeHost: (TerminalEngine) -> any TerminalSurfaceHost

  /// `makeHost` exists so tests can substitute recording engines; the app
  /// uses the real ones.
  init(
    engine: TerminalEngine,
    makeHost: @escaping (TerminalEngine) -> any TerminalSurfaceHost = { $0.makeHost() }
  ) {
    self.engine = engine
    self.makeHost = makeHost
  }

  var openSessionIDs: Set<TerminalSession.ID> {
    hosts.values.reduce(into: []) { $0.formUnion($1.openSessionIDs) }
  }

  func open(_ session: TerminalSession) throws {
    try host(for: engine).open(session)
    owner[session.id] = engine
  }

  func close(_ id: TerminalSession.ID) {
    host(owning: id)?.close(id)
    owner[id] = nil
  }

  func focus(_ id: TerminalSession.ID) {
    host(owning: id)?.focus(id)
  }

  func view(for id: TerminalSession.ID) -> NSView? {
    host(owning: id)?.view(for: id)
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    self.theme = theme
    self.appearance = appearance
    for host in hosts.values {
      host.apply(theme, appearance: appearance)
    }
  }

  private func host(owning id: TerminalSession.ID) -> (any TerminalSurfaceHost)? {
    owner[id].flatMap { hosts[$0] }
  }

  /// Created on demand and styled to match the others straight away.
  private func host(for engine: TerminalEngine) -> any TerminalSurfaceHost {
    if let existing = hosts[engine] { return existing }
    let created = makeHost(engine)
    created.delegate = self
    if let theme, let appearance {
      created.apply(theme, appearance: appearance)
    }
    hosts[engine] = created
    return created
  }
}

/// Child hosts report to this host; it reports on as itself, so the registry
/// sees one host whichever engine raised the event.
extension MultiEngineHost: TerminalHostDelegate {
  func terminalHost(_ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String) {
    delegate?.terminalHost(self, didRetitle: id, to: title)
  }

  /// Ownership is kept here: the registry answers an exit by calling
  /// `close`, which must still reach the engine that holds the surface.
  func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID, code: Int32) {
    delegate?.terminalHost(self, didExit: id, code: code)
  }

  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID) {
    delegate?.terminalHost(self, didSeeActivityIn: id)
  }

  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID) {
    delegate?.terminalHost(self, didFocus: id)
  }
}
