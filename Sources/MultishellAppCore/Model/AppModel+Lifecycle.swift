import MultishellCore
import MultishellProcess

extension AppModel {
  /// Shells actually running, as opposed to saved tabs waiting to be opened.
  public var liveTerminalCount: Int { liveSessionIDs.count }

  /// Every live shell is a pty that quitting kills, unless `multishell quit` already asked.
  public var asksBeforeQuitting: Bool { liveTerminalCount > 0 && !quitsWithoutAsking }

  /// The quick switcher's field, a rename's or a find bar's, each known to the
  /// model while it edits, so one opened while launch ran keeps the keyboard.
  private var isSwitcherRenameOrFindEditing: Bool {
    quickSwitcher != nil || renamingWorktreeID != nil || renamingTabID != nil
      || findFieldTargetID != nil
  }

  func liveTerminalCount(in worktree: Worktree.ID) -> Int {
    workspace.sessions(in: worktree).filter { liveSessionIDs.contains($0.id) }.count
  }

  /// Opens the socket and asks git what each project actually has, over a
  /// workspace already read from disk. Terminals are not restored.
  public func start() async {
    guard startMessageSource() else { return }
    // On the main actor, before `start` first yields, so no tab can open ahead.
    presentingFailure { try refreshAppLaunchFiles(platform.bundledHelper) }
    // All that bounds the drops directory; no terminal waits on it.
    let sweep = sweepDropCopies
    Task { await runOnDispatch(sweep) }
    await refreshAll()
    // With no project nothing else arms the watcher, which the themes folder needs.
    await rearmWatcher()
    reconcileSessions(takingFocus: !isSwitcherRenameOrFindEditing)
    startStatusPolling()
    await refreshLoginEnvironment()
  }

  /// Opens the inbound channel. `false` where another copy of this build
  /// holds it: this one hands over to it and quits; see state-and-store.md.
  func startMessageSource() -> Bool {
    do {
      try messageSource.start()
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
    messageSource.stop()
    // A run's timeout is the app's own timer, gone with it.
    oneShotRunner.stopAll()
  }
}
