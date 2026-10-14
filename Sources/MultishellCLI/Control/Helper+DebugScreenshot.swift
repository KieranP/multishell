import Foundation
import MultishellCore

extension Helper {
  private static let maximumScreenshotNameAttempts = 100

  /// Written here, so the app never writes to a path a request names. No FILE
  /// is a new one under /tmp; either way the path is printed.
  static func runDebugScreenshot(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let topic = ControlCommand.debug.rawValue
    let (words, optionWords) = positionals(arguments)
    guard words.count <= 1 else {
      throw UsageError("debug screenshot takes one FILE at most", topic: topic)
    }
    let pane = try CommandOptions(optionWords, valued: ["pane"], topic: topic)["pane"].map { text in
      try tabOrPaneID(text, topic: topic)
    }
    let encoded = try output(of: .screenshot(pane: pane), environment: environment) ?? ""
    guard let image = Data(base64Encoded: encoded), !image.isEmpty else {
      throw ControlRefused(refusal: .screenshotFailed)
    }
    let file = try writeScreenshot(image, to: words.first.map(absolutePath))
    try printJSON(["path": file.path])
    return 0
  }

  /// `nil` is a new file under /tmp, named for `date`.
  static func writeScreenshot(
    _ image: Data,
    to path: String?,
    at date: Date = Date(),
  ) throws -> URL {
    if let path {
      let file = URL(fileURLWithPath: path)
      try image.write(to: file)
      return file
    }
    // /tmp is shared, so a name already there, or a link planted at it, is passed over.
    let stem = temporaryScreenshotStem(at: date)
    for attempt in 0..<maximumScreenshotNameAttempts {
      let file = URL(fileURLWithPath: stem + (attempt == 0 ? "" : "-\(attempt)") + ".png")
      do {
        try image.write(to: file, options: .withoutOverwriting)
        return file
      } catch let error as CocoaError where error.code == .fileWriteFileExists {
        continue
      }
    }
    throw CocoaError(.fileWriteFileExists)
  }

  /// Named by the moment to the millisecond, so screenshots in a row keep apart.
  private static func temporaryScreenshotStem(at date: Date) -> String {
    let format = DateFormatter()
    format.locale = Locale(identifier: "en_US_POSIX")
    format.dateFormat = "yyyyMMdd-HHmmss-SSS"
    return "/tmp/multishell-screenshot-\(format.string(from: date))"
  }
}
