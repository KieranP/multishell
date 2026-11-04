import MultishellCore

extension Helper {
  static func runWindow(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.window.rawValue
    switch (arguments.first, arguments.count) {
    case ("size", 3):
      guard let width = points(arguments.dropFirst().first), let height = points(arguments.last)
      else { break }
      return try ask(.resizeWindow(width: width, height: height), environment: environment)

    case ("full-screen", 2) where ["on", "off"].contains(arguments.last):
      return try ask(.setFullScreen(on: arguments.last == "on"), environment: environment)

    case ("sidebar-width", 2), ("panel-width", 2):
      guard let width = points(arguments.last) else { break }
      let panel: ResizablePanel = arguments.first == "sidebar-width" ? .sidebar : .filesPanel
      return try ask(.setPanelWidth(panel, width: width), environment: environment)

    default: break
    }
    throw UsageError(
      "window needs: size WIDTH HEIGHT, sidebar-width WIDTH or panel-width WIDTH, in points, "
        + "or full-screen on|off",
      topic: topic,
    )
  }

  /// A length in points no screen nears: `inf` and `1e300` never reach AppKit.
  private static func points(_ text: String?) -> Double? {
    guard let points = text.flatMap(Double.init), points >= 1, points <= 100_000 else { return nil }
    return points
  }
}
