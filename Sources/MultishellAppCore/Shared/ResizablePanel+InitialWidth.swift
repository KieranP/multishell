import MultishellCore

extension ResizablePanel {
  /// Where the panel starts on a machine that has never moved its edge.
  public var initialWidth: Double {
    switch self {
    case .filesPanel: FilesPanelWidth.initial
    case .sidebar: SidebarWidth.initial
    }
  }
}
