import MultishellCore
import MultishellProcess

extension AppModel {
  /// Opens the socket and asks git what each project actually has, over a
  /// workspace already read from disk. Terminals are not restored.
  public func start() async {
    guard startStateSource() else { return }
    // On the main actor, before `start` first yields, so no tab can open ahead.
    presentingFailure { try refreshAppLaunchFiles(platform.bundledHelper) }
    // All that bounds the drops directory; no terminal waits on it.
    let sweep = sweepPromisedDropCopies
    Task { await runOnDispatch(sweep) }
    await refreshAll()
    reconcileSessions(takingFocus: true)
    startStatusPolling()
    await refreshLoginEnvironment()
  }

  /// Opens the inbound channel. `false` where another copy of this build
  /// holds it: this one hands over to it and quits; see state-and-store.md.
  func startStateSource() -> Bool {
    do {
      try stateSource.start()
      return true
    } catch let failure as SocketFailure where failure.kind == .inUse {
      isYieldingToRunningInstance = true
      pendingSave?.cancel()
      platform.handOverToRunningInstance()
      // Still here: the platform could not quit, so say what is wrong.
      present(failure)
      return false
    } catch {
      present(error)
      return true
    }
  }

  /// On quit: the last save, and the socket file unlinked so the next
  /// launch does not have to probe it.
  public func shutDown() {
    saveNow()
    stateSource.stop()
  }
}
