import Foundation
import MultishellCore

extension Helper {
  /// Read here and sent as text, so the app opens no path a request names;
  /// `-` reads standard input.
  static func runDebugServices(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let topic = ControlCommand.debug.rawValue
    switch (arguments.first, arguments.count) {
    case ("stand-in", 2):
      let source = arguments[arguments.index(after: arguments.startIndex)]
      guard source == "-" || !source.hasPrefix("-") else {
        throw UsageError(
          "debug services stand-in takes a FILE, or - for standard input",
          topic: topic,
        )
      }
      let data =
        source == "-"
        ? FileHandle.standardInput.readDataToEndOfFile()
        : try Data(contentsOf: URL(fileURLWithPath: absolutePath(source)))
      let json = String(decoding: data, as: UTF8.self)
      do {
        return try ask(.standInServices(json: json), environment: environment, timeout: nil)
      } catch let tooLong as ControlRequestTooLong {
        throw ControlRequestTooLong(
          byteCount: tooLong.byteCount,
          advice: "a stand-in goes whole, so give it fewer pull requests and runs",
        )
      }

    case ("clear", 1):
      return try ask(.standInServices(json: nil), environment: environment, timeout: nil)

    default:
      throw UsageError("debug services needs: stand-in FILE, stand-in - or clear", topic: topic)
    }
  }
}
