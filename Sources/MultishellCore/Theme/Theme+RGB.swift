import Foundation

extension Theme {
  /// One of the 16 ANSI colours, only that slot parsed: a row asks for a few, a render
  /// many. Grey when unparsable, so a hand-edited theme cannot leave a terminal unpainted.
  public func ansiRGB(_ slot: Int) -> RGB {
    let grey = RGB(red: 128, green: 128, blue: 128)
    guard ansi.indices.contains(slot) else { return grey }
    return HexColor.parse(ansi[slot]) ?? grey
  }

  public func ansiRGB(_ color: ANSIColor) -> RGB {
    ansiRGB(color.rawValue)
  }

  public var backgroundRGB: RGB { HexColor.parse(background) ?? .black }
  public var foregroundRGB: RGB {
    HexColor.parse(foreground) ?? .white
  }
  public var selectionBackgroundRGB: RGB {
    HexColor.parse(selectionBackground) ?? RGB(red: 64, green: 96, blue: 144)
  }

  /// The line round the focused pane: a colour, `""` for none, absent for
  /// the selection colour. A typo reads as absent, not as none.
  public var focusRingRGB: RGB? {
    guard let focusRing else { return selectionBackgroundRGB }
    guard let text = focusRing.trimmedOrNil else { return nil }
    return HexColor.parse(text) ?? selectionBackgroundRGB
  }
}
