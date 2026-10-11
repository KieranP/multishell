import MultishellCore

extension Helper {
  static func runBoard(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    guard arguments.first == "list", arguments.count == 1 else {
      throw UsageError("board needs: list", topic: ControlCommand.board.rawValue)
    }
    return try ask(.listBoard, environment: environment)
  }
}
