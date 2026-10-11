import MultishellCore

extension Helper {
  static func runSidebar(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    guard arguments.first == "list", arguments.count == 1 else {
      throw UsageError("sidebar needs: list", topic: ControlCommand.sidebar.rawValue)
    }
    return try ask(.listSidebar, environment: environment)
  }
}
