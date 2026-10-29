import Foundation
import MultishellCore

/// Where the sidebar's and the Files panel's per-machine widths are kept;
/// whether the panel is open is not kept (files.md).
@MainActor
enum PanelWidthStorage {
  static let sidebarKey = "sidebarWidth"
  static let filesPanelKey = "filesPanelWidth"

  /// A debug build's own suite, so a scratch run never moves the installed
  /// app's edges; see Docs/develop/state-on-disk.md.
  static let defaults: UserDefaults =
    Paths.userDefaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard

  static func key(of panel: ResizablePanel) -> String {
    switch panel {
    case .filesPanel: filesPanelKey
    case .sidebar: sidebarKey
    }
  }
}
