import AppKit
import MultishellAppCore
import MultishellCore
import MultishellGitKit

/// The model with the Mac's surface type fixed. Every view names this.
typealias AppModel = MultishellAppCore.AppModel<NSView>

extension AppModel {
  /// The real dependencies: both engines behind one host, the kqueue
  /// watcher, the Unix socket, the notification centre, and AppKit through
  /// `platform`.
  convenience init(platform: MacPlatform) {
    let (store, loadError) = WorkspaceStore.restored()
    self.init(
      store: store,
      host: MultiEngineHost(engine: store.workspace.terminalEngine) { $0.makeHost() },
      worktrees: try? WorktreeCoordinator(),
      watcher: DispatchDirectoryWatcher(),
      platform: platform,
      stateSource: SocketStateSource(),
      notifier: UserNotificationNotifier(),
      loadError: loadError
    )
  }

  var metrics: UIMetrics {
    UIMetrics(fontSize: workspace.appearance.uiFontSize)
  }
}
