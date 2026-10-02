import Foundation

extension Theme {
  /// What each `ansi` slot is called. The slot's name, not the colour's: a
  /// project tinted from it follows whatever the current theme has there.
  public static var ansiSlotNames: [String] {
    [
      t("ansi.black"), t("ansi.red"), t("ansi.green"), t("ansi.yellow"),
      t("ansi.blue"), t("ansi.magenta"), t("ansi.cyan"), t("ansi.white"),
      t("ansi.bright-black"), t("ansi.bright-red"), t("ansi.bright-green"),
      t("ansi.bright-yellow"), t("ansi.bright-blue"), t("ansi.bright-magenta"),
      t("ansi.bright-cyan"), t("ansi.bright-white"),
    ]
  }
}
