import MultishellCore

/// One host that fronts every engine. A session keeps the engine that opened
/// it for life, and engines are created on first use.
@MainActor
public final class MultiEngineHost<Surface>: TerminalSurfaceHost {
  /// Engine for sessions opened from now on.
  public var engine: TerminalEngine

  public weak var delegate: (any TerminalHostDelegate)?

  private var hosts: [TerminalEngine: any TerminalSurfaceHost<Surface>] = [:]
  private var owner: [TerminalSession.ID: TerminalEngine] = [:]
  private var theme: Theme?
  private var appearance: Appearance?
  private let makeHost: (TerminalEngine) -> any TerminalSurfaceHost<Surface>

  /// `makeHost` builds the platform's engine for a kind: the real ones in
  /// the app, recording fakes in tests.
  public init(
    engine: TerminalEngine,
    makeHost: @escaping (TerminalEngine) -> any TerminalSurfaceHost<Surface>
  ) {
    self.engine = engine
    self.makeHost = makeHost
  }

  public var openSessionIDs: Set<TerminalSession.ID> {
    hosts.values.reduce(into: []) { $0.formUnion($1.openSessionIDs) }
  }

  /// An engine that threw is told to let go: it may have registered the
  /// surface first, and a retry on another engine would take the entry.
  public func open(_ session: TerminalSession) throws {
    owner[session.id] = engine
    do {
      try host(for: engine).open(session)
    } catch {
      host(for: engine).close(session.id)
      owner[session.id] = nil
      throw error
    }
  }

  public func close(_ id: TerminalSession.ID) {
    host(owning: id)?.close(id)
    owner[id] = nil
  }

  public func focus(_ id: TerminalSession.ID) {
    host(owning: id)?.focus(id)
  }

  @discardableResult
  public func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    host(owning: id)?.paste(text, into: id) ?? false
  }

  public func view(for id: TerminalSession.ID) -> Surface? {
    host(owning: id)?.view(for: id)
  }

  public func apply(_ theme: Theme, appearance: Appearance) {
    self.theme = theme
    self.appearance = appearance
    for host in hosts.values {
      host.apply(theme, appearance: appearance)
    }
  }

  private func host(owning id: TerminalSession.ID) -> (any TerminalSurfaceHost<Surface>)? {
    owner[id].flatMap { hosts[$0] }
  }

  /// Created on demand and styled to match the others straight away.
  private func host(for engine: TerminalEngine) -> any TerminalSurfaceHost<Surface> {
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
  public func terminalHost(
    _ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String
  ) {
    delegate?.terminalHost(self, didRetitle: id, to: title)
  }

  /// Ownership is kept here: the registry answers an exit by calling
  /// `close`, which must still reach the engine that holds the surface.
  public func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID, code: Int32) {
    delegate?.terminalHost(self, didExit: id, code: code)
  }

  public func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID) {
    delegate?.terminalHost(self, didSeeActivityIn: id)
  }

  public func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID) {
    delegate?.terminalHost(self, didFocus: id)
  }

  /// Forwarded as itself, or the protocol's default would turn it back
  /// into plain activity here.
  public func terminalHost(
    _ host: any TerminalHost, didFinishCommandIn id: TerminalSession.ID, exitCode: Int32?
  ) {
    delegate?.terminalHost(self, didFinishCommandIn: id, exitCode: exitCode)
  }
}
