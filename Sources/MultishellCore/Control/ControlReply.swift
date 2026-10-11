import Foundation

/// The app's answer to a `ControlRequest`, one line on its connection.
public struct ControlReply: Codable, Equatable, Sendable {
  public static let done = Self(output: nil, refusal: nil)

  /// JSON for the helper to print, `nil` for a request that prints nothing.
  public let output: String?
  public let refusal: ControlRefusal?

  public static func output(_ text: String) -> Self { Self(output: text, refusal: nil) }

  public static func refused(_ refusal: ControlRefusal) -> Self {
    Self(output: nil, refusal: refusal)
  }

  public static func parse(_ line: String) -> Self? {
    try? JSONDecoder().decode(Self.self, from: Data(line.utf8))
  }

  public func encodedLine() throws -> String {
    try JSONEncoder.socketLine(self)
  }
}
