import AppKit
import MultishellAppCore
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// The real dependencies: the libghostty host, the FSEvents watcher, the
  /// socket, the notification centre, and AppKit through `platform`.
  convenience init(platform: MacPlatform) {
    let (store, loadError) = WorkspaceStore.restored()
    self.init(
      store: store,
      host: GhosttyTerminalHost(),
      coordinator: try? WorktreeCoordinator(),
      watcher: FSEventsDirectoryWatcher(),
      platform: platform,
      messageSource: SocketMessageSource(),
      notifier: UserNotificationNotifier(),
      loadError: loadError,
    )
  }
}
