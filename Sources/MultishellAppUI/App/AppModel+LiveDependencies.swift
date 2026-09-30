import AppKit
import MultishellAppCore
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// The real dependencies: the libghostty host, the kqueue watcher, the
  /// socket, the notification centre, and AppKit through `platform`.
  convenience init(platform: MacPlatform) {
    let (store, loadError) = WorkspaceStore.restored()
    self.init(
      store: store,
      host: GhosttyTerminalHost(),
      coordinator: try? WorktreeCoordinator(),
      watcher: DispatchDirectoryWatcher(),
      platform: platform,
      stateSource: SocketStateSource(),
      notifier: UserNotificationNotifier(),
      loadError: loadError
    )
  }
}
