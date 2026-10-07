/// What a double-click on a title bar does, as the system setting says.
public enum TitleBarDoubleClickAction: Equatable, Sendable {
  case zoom
  case minimize
  case ignore

  /// `AppleActionOnDoubleClick`'s value, where anything else zooms as macOS
  /// itself does.
  public init(systemSetting: String?) {
    switch systemSetting {
    case "Minimize": self = .minimize
    case "None": self = .ignore
    default: self = .zoom
    }
  }
}
