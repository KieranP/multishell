import AppKit
import MultishellAppCore
import MultishellCore
import MultishellGitKit

/// The model with the Mac's surface type fixed. Every view names this.
typealias AppModel = MultishellAppCore.AppModel<NSView>

extension AppModel {
  /// The real dependencies: the libghostty host, the kqueue watcher, the
  /// socket, the notification centre, and AppKit through `platform`.
  convenience init(platform: MacPlatform) {
    let (store, loadError) = WorkspaceStore.restored()
    self.init(
      store: store,
      host: GhosttyTerminalHost(),
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
