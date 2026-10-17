import Foundation
import MultishellGitKit

/// How a file tab reads a file's bytes as text: UTF-8, else the encoding a
/// text editor would guess, as the open rule admits any file typed as text.
enum TextDecoding {
  private static let guessedEncodings: [NSNumber] = [
    String.Encoding.windowsCP1252, .isoLatin1, .macOSRoman, .shiftJIS,
  ].map { NSNumber(value: $0.rawValue) }

  /// The text and its encoding, `nil` for a file that is not text.
  static func decode(_ data: Data) -> (text: String, encoding: String.Encoding)? {
    guard !data.prefix(GitBinaryRule.checkedByteCount).contains(0) else { return nil }
    if let text = String(data: data, encoding: .utf8) { return (text, .utf8) }
    var converted: NSString?
    let raw = NSString.stringEncoding(
      for: data,
      encodingOptions: [
        .suggestedEncodingsKey: guessedEncodings, .allowLossyKey: false,
      ],
      convertedString: &converted,
      usedLossyConversion: nil,
    )
    guard raw != 0, let converted else { return nil }
    return (converted as String, String.Encoding(rawValue: raw))
  }
}
