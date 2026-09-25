import Foundation

extension Theme {
  /// The 16 ANSI colours, with any unparsable entry falling back to grey so
  /// a hand-edited theme file cannot leave a terminal unpaintable.
  public var ansiRGB: [RGB] {
    ansi.indices.map(ansiRGB)
  }

  /// One of them, parsing that one alone: a row draws a few, a render many.
  public func ansiRGB(_ slot: Int) -> RGB {
    let grey = RGB(red: 128, green: 128, blue: 128)
    guard ansi.indices.contains(slot) else { return grey }
    return HexColor.parse(ansi[slot]) ?? grey
  }

  public var backgroundRGB: RGB { HexColor.parse(background) ?? .black }
  public var foregroundRGB: RGB {
    HexColor.parse(foreground) ?? .white
  }
  public var selectionRGB: RGB {
    HexColor.parse(selectionBackground) ?? RGB(red: 64, green: 96, blue: 144)
  }

  /// The line round the focused pane: a colour, `""` for none, absent for
  /// the selection colour. A typo reads as absent, not as none.
  public var focusRingRGB: RGB? {
    guard let focusRing else { return selectionRGB }
    let text = focusRing.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else { return nil }
    return HexColor.parse(text) ?? selectionRGB
  }
}
