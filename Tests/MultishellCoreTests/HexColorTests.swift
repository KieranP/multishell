import Foundation
import Testing

@testable import MultishellCore

@Suite
struct HexColorTests {
  @Test func parsesSixDigitHexWithAndWithoutHash() {
    #expect(HexColor.parse("#5aa9f8") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
    #expect(HexColor.parse("5aa9f8") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
  }

  @Test func expandsThreeDigitShorthand() {
    #expect(HexColor.parse("#f0a") == RGB(red: 0xff, green: 0x00, blue: 0xaa))
  }

  @Test func rejectsMalformedInput() {
    #expect(HexColor.parse("") == nil)
    #expect(HexColor.parse("#12345") == nil)
    #expect(HexColor.parse("#gggggg") == nil)
  }

  @Test func surroundingWhitespaceIsForgiven() {
    #expect(HexColor.parse(" #5aa9f8 ") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
    #expect(HexColor.parse("#5a a9f8") == nil, "but not a space inside")
  }

  @Test func aLeadingSignIsNotAColour() {
    // `UInt32(_:radix:)` accepts "+abcde" as 0xabcde; a theme file must not.
    #expect(HexColor.parse("#+abcde") == nil)
    #expect(HexColor.parse("+abcde") == nil)
    #expect(HexColor.parse("-abcde") == nil)
  }

  @Test func everyBuiltinThemeParsesCompletely() {
    for theme in Theme.builtins {
      #expect(
        theme.ansi.allSatisfy { HexColor.parse($0) != nil }, "\(theme.id) has a bad ANSI colour")
      #expect(HexColor.parse(theme.background) != nil)
      #expect(HexColor.parse(theme.foreground) != nil)
      #expect(HexColor.parse(theme.cursor) != nil)
      #expect(HexColor.parse(theme.selectionBackground) != nil)
      #expect(theme.focusRingRGB != nil, "\(theme.id) draws no focus ring")
      #expect(
        theme.focusRingRGB != theme.selectionRGB,
        "\(theme.id) rings in its selection colour, which is mixed to sit under text")
      #expect(
        theme.inactivePaneOpacity > Theme.minimumInactivePaneOpacity
          && theme.inactivePaneOpacity < 1,
        "\(theme.id) fades unfocused panes by nothing, or by all")
    }
  }
}

/// The focus ring reads three spellings of one key; see `Theme.focusRing`.
@Suite
struct FocusRingTests {
  private func theme(ring: String?) -> Theme {
    var theme = Theme.multishellDark
    theme.focusRing = ring
    return theme
  }

  @Test func aColourIsThatColour() {
    #expect(theme(ring: "#6cc763").focusRingRGB == RGB(red: 0x6c, green: 0xc7, blue: 0x63))
    #expect(theme(ring: " 6cc763 ").focusRingRGB == RGB(red: 0x6c, green: 0xc7, blue: 0x63))
  }

  @Test func anEmptyStringIsNoRingAtAll() {
    #expect(theme(ring: "").focusRingRGB == nil)
    #expect(theme(ring: "   ").focusRingRGB == nil, "whitespace is how a JSON file says empty")
  }

  @Test func theKeyLeftOutIsTheSelectionColour() {
    #expect(theme(ring: nil).focusRingRGB == Theme.multishellDark.selectionRGB)
  }

  /// A typo costs the colour, not the ring: reading it as off would
  /// silently remove the thing the key was setting.
  @Test func aColourThatWillNotParseFallsBackRatherThanTurningTheRingOff() {
    #expect(theme(ring: "cornflower").focusRingRGB == Theme.multishellDark.selectionRGB)
    #expect(theme(ring: "#12345").focusRingRGB == Theme.multishellDark.selectionRGB)
  }
}

@Suite
struct HexColorAlphaTests {
  @Test func aTrailingAlphaIsReadAndIgnored() {
    #expect(HexColor.parse("#5aa9f8ff") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
    #expect(HexColor.parse("5aa9f800") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
    #expect(HexColor.parse("#f0f8") == RGB(red: 0xff, green: 0x00, blue: 0xff))
  }

  @Test func otherLengthsAndBadAlphaDigitsAreStillRefused() {
    for text in ["#5aa9f8f", "#5aa9f8fff", "#5aa9f8zz", "#f0fz", "#ab", "#abcde"] {
      #expect(HexColor.parse(text) == nil, "\(text)")
    }
  }
}

@Suite
struct ShellQuotingTests {
  @Test func plainArgumentsPassThroughAndOthersAreSingleQuoted() {
    #expect(ShellQuoting.commandLine(["/usr/bin/top", "-o", "cpu"]) == "/usr/bin/top -o cpu")
    #expect(ShellQuoting.quote("My Projects") == "'My Projects'")
    #expect(ShellQuoting.quote("it's") == #"'it'\''s'"#)
    #expect(ShellQuoting.quote("$HOME") == "'$HOME'")
    #expect(ShellQuoting.quote("") == "''")
  }

  /// The shell that receives the line must give back exactly the arguments.
  @Test func theShellUnquotesToTheOriginalArguments() async throws {
    let arguments = ["My Projects/app", "it's", "$HOME", "", "a\"b", "back\\slash", "tab\there"]
    let script =
      "for a in " + ShellQuoting.commandLine(arguments) + "; do printf '%s\\n' \"$a\"; done"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", script]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let lines = String(decoding: data, as: UTF8.self).split(
      separator: "\n", omittingEmptySubsequences: false
    ).dropLast().map(String.init)
    #expect(lines == arguments)
  }
}
