import CoreGraphics

@testable import MultishellAppUI

extension UIMetrics {
  /// What a page has to fit: the window less the sidebar and its rule, and
  /// less the page's header band.
  static var settingsPageSize: CGSize {
    CGSize(
      width: settingsWindowSize.width - settingsSidebarWidth - 1,
      height: settingsWindowSize.height - settingsHeaderHeight,
    )
  }
}
