import MultishellCore
import MultishellProcess

extension AppModel {
  /// Restores the sidebar from disk, then asks git what each project
  /// actually has. Terminals are not restored; only the tree is.
  public func start() async {
    guard startStateSource() else { return }
    host.claimSharedFiles()
    // On the main actor, before `start` first yields, so no tab can open ahead.
    if let failure = refreshAppLaunchFiles(platform.bundledHelper) { present(failure) }
    // All that bounds the drops directory; no terminal waits on it.
    let sweep = sweepPromisedDropCopies
    Task { await offMain(sweep) }
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
      yieldingToRunningInstance = true
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
    host.shutDown()
  }
}
