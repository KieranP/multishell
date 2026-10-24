import Foundation

/// A CLI's output with its terminal styling taken out, for a name or an error
/// shown in the sidebar, a banner or VoiceOver.
enum PrintableText {
  /// ECMA-48's forms: CSI with any parameter byte; OSC to its bell or terminator;
  /// DCS, SOS, PM and APC to theirs; nF, as `sgr0`'s `ESC ( B`; any other two-byte.
  private static let escapeSequence = [
    #"\x1B\[[0-?]*[ -/]*[@-~]"#, #"\x1B\][^\x07\x1B]*(\x07|\x1B\\)"#,
    #"\x1B[PX^_][^\x1B]*\x1B\\"#, #"\x1B[ -/]+[0-~]"#, #"\x1B[0-Z\\^-~]"#,
  ].joined(separator: "|")

  /// Line breaks become `\n` and stay, with tabs; other control characters go.
  /// A joiner or a direction mark is part of the text, not a control.
  static func of(_ text: String) -> String {
    let unstyled = text.replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: escapeSequence, with: "", options: .regularExpression)
    let kept = unstyled.unicodeScalars.filter { scalar in
      scalar.properties.generalCategory != .control || scalar == "\n" || scalar == "\t"
    }
    return String(String.UnicodeScalarView(kept))
  }
}
