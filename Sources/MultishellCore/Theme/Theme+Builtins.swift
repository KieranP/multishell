extension Theme {
  public static let builtins: [Theme] = [.multishellDark, .multishellLight]

  /// Its focus ring is its own blue: the selection colour is mixed to sit
  /// under text, and reads as a smudge as a one-point line.
  static let multishellDark = Theme(
    id: "multishell.dark",
    name: "Multishell Dark",
    isDark: true,
    background: "#121215",
    foreground: "#e4e4e7",
    cursor: "#e4e4e7",
    selectionBackground: "#2f4f7a",
    ansi: [
      "#26262b", "#ff6b60", "#6cc763", "#e5c07b",
      "#5aa9f8", "#bf5af2", "#64d2ff", "#c8c8cd",
      "#4a4a52", "#ff8b82", "#8fdb87", "#f0d49b",
      "#7fbdff", "#d191f5", "#8fe0ff", "#f2f2f5",
    ],
    focusRing: "#5aa9f8",
    inactivePaneOpacity: 0.8
  )

  static let multishellLight = Theme(
    id: "multishell.light",
    name: "Multishell Light",
    isDark: false,
    background: "#fbfbfa",
    foreground: "#26262b",
    cursor: "#26262b",
    selectionBackground: "#b9d5f5",
    ansi: [
      "#3c3c43", "#c7392f", "#3f8c38", "#9a7218",
      "#2f6fd0", "#8b3fbd", "#237f96", "#dcdcdf",
      "#6b6b73", "#e05548", "#54a84b", "#b98d28",
      "#4a8ae8", "#a55dd4", "#3399b0", "#f7f7f8",
    ],
    focusRing: "#2f6fd0",
    inactivePaneOpacity: 0.8
  )
}
