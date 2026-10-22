/// One open window as `multishell info` lists it, in points.
public struct PlatformWindow: Encodable, Equatable, Sendable {
  /// The platform's own name for it, which `ui hide` matches on.
  let identifier: String
  let title: String
  let isKey: Bool
  let width: Double
  let height: Double
  let isFullScreen: Bool
  /// The title of a sheet over it, `nil` for none.
  let sheet: String?

  public init(
    identifier: String,
    title: String,
    isKey: Bool,
    width: Double,
    height: Double,
    isFullScreen: Bool,
    sheet: String?,
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
