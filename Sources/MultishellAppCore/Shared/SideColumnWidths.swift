import MultishellCore

/// The sidebar's and the Files panel's widths as drawn, each at most half the
/// room the other leaves, solved together; see files.md.
public struct SideColumnWidths: Equatable, Sendable {
  public let sidebar: Double
  /// Zero while the panel is shut.
  public let filesPanel: Double

  init(sidebar: Double, filesPanel: Double) {
    self.sidebar = sidebar
    self.filesPanel = filesPanel
  }

  /// `storedFilesPanel` is `nil` while the panel is shut. Where both sides are
  /// past half their room the window splits in thirds, the tabs taking one.
  public init(windowWidth: Double, storedSidebar: Double, storedFilesPanel: Double?) {
    guard let storedPanel = storedFilesPanel else {
      self.init(
        sidebar: storedSidebar.clamped(
          to: SidebarWidth.range(inWindowOfWidth: windowWidth, besidePanelOf: 0)
        ),
        filesPanel: 0,
      )
      return
    }
    let third = windowWidth / 3
    let (sidebar, panel): (Double, Double) =
      if storedSidebar + 2 * storedPanel <= windowWidth,
        2 * storedSidebar + storedPanel <= windowWidth
      {
        (storedSidebar, storedPanel)
      } else if storedSidebar <= third {
        (storedSidebar, (windowWidth - storedSidebar) / 2)
      } else if storedPanel <= third {
        ((windowWidth - storedPanel) / 2, storedPanel)
      } else {
        (third, third)
      }
    self.init(
      sidebar: max(SidebarWidth.minimum, sidebar),
      filesPanel: max(FilesPanelWidth.minimum, panel),
    )
  }
}
