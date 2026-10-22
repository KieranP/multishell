/// One item of the menu bar as `multishell ui menu` lists it.
public struct PlatformMenuItem: Encodable, Equatable, Sendable {
  /// Its titles from the bar down: `["View", "Enable Debug Tools"]`.
  let path: [String]
  let isEnabled: Bool
  /// Ticked, as a toggle that is on is.
  let isChecked: Bool

  public init(path: [String], isEnabled: Bool, isChecked: Bool) {
    self.path = path
    self.isEnabled = isEnabled
    self.isChecked = isChecked
  }
}
