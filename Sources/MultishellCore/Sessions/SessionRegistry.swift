import Foundation

/// Drives a `TerminalHost` from the store, so no view ever opens a terminal
/// directly. Call `reconcile()` after any change to the session list.
@MainActor
public final class SessionRegistry {
  public struct Failure: Sendable {
    public let sessionID: TerminalSession.ID
    public let error: any Error
  }

  private let store: WorkspaceStore
  private let host: any TerminalHost

  /// Forwarded activity, for the GUI to mark background tabs. Not stored in
  /// the workspace because it is about what the user has seen, not state.
  public var onActivity: (@MainActor (TerminalSession.ID) -> Void)?

  /// The foreground command of a shell returned. Distinct from activity so
  /// the GUI can clear a Working state the engine has evidence against.
  public var onCommandFinished: (@MainActor (TerminalSession.ID, Int32?) -> Void)?

  /// The title the shell reports through OSC. Runtime, like activity: a
  /// prompt would otherwise schedule a save per keystroke.
  public var onRetitle: (@MainActor (TerminalSession.ID, String) -> Void)?

  /// Fired whenever the live session set may have changed. The host is not
  /// observable, so the GUI mirrors `liveSessionIDs` from here.
  public var onLiveSessionsChanged: (@MainActor () -> Void)?

  public init(store: WorkspaceStore, host: any TerminalHost) {
    self.store = store
    self.host = host
    host.delegate = self
  }

  /// Sessions the host has a live process for.
  public var liveSessionIDs: Set<TerminalSession.ID> { host.openSessionIDs }

  /// Opens sessions the host is missing and closes ones it should not have.
  /// `shouldBeLive` keeps restored tabs cold; failures stay in the store.
  @discardableResult
  public func reconcile(
    shouldBeLive: (TerminalSession) -> Bool = { _ in true },
    prepare: (TerminalSession) -> TerminalSession = { $0 }
  ) -> [Failure] {
    let wanted = store.workspace.sessions.filter(shouldBeLive)
    let wantedIDs = Set(wanted.map(\.id))
    let open = host.openSessionIDs

    for id in open.subtracting(wantedIDs) {
      host.close(id)
    }

    var failures: [Failure] = []
    for session in wanted where !open.contains(session.id) {
      do {
        try host.open(prepare(session))
      } catch {
        failures.append(Failure(sessionID: session.id, error: error))
      }
    }
    onLiveSessionsChanged?()
    return failures
  }

  public func focusActiveSession() {
    guard
      let worktreeID = store.workspace.selectedWorktreeID,
      let tab = store.workspace.activeTab(in: worktreeID)
    else { return }
    host.focus(tab.focusedSessionID)
  }
}

extension SessionRegistry: TerminalHostDelegate {
  public func terminalHost(
    _ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String
  ) {
    onRetitle?(id, title)
    onActivity?(id)
  }

  public func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID) {
    onActivity?(id)
  }

  public func terminalHost(
    _ host: any TerminalHost, didFinishCommandIn id: TerminalSession.ID, exitCode: Int32?
  ) {
    onCommandFinished?(id, exitCode)
  }

  public func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID) {
    store.focusSession(id)
  }

  /// The process is already gone, so the surface must go too; leaving it
  /// until the next reconcile shows a dead terminal under a missing tab.
  public func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID, code: Int32) {
    store.closeSession(id)
    host.close(id)
    focusActiveSession()
    onLiveSessionsChanged?()
  }
}
