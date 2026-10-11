/// One open window as `multishell info` lists it, in points.
public struct PlatformWindow: Encodable, Equatable, Sendable {
  /// The platform's own name for it, which `ui hide` matches on.
  public let identifier: String
  public let title: String
  public let isKey: Bool
  public let width: Double
  public let height: Double
  public let isFullScreen: Bool
  /// The title of a sheet over it, `nil` for none.
  public let sheet: String?

  public init(
    identifier: String,
    title: String,
    isKey: Bool,
    width: Double,
    height: Double,
    sheet: String?,
    isFullScreen: Bool = false,
  ) {
    self.identifier = identifier
    self.title = title
    self.isKey = isKey
    self.width = width
    self.height = height
    self.isFullScreen = isFullScreen
    self.sheet = sheet
  }
}
