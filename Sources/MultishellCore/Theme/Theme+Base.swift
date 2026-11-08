extension Theme {
  /// Multishell Dark or Light, whichever matches `isDark`: what every key the
  /// theme leaves out, or sets badly, falls back on.
  var base: Theme { isDark ? .multishellDark : .multishellLight }
}
