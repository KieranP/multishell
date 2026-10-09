/// The plugin OpenCode is given, since it runs no hook command. Here and not
/// in `Resources`, which the helper cannot reach; see Docs/design/agents.md.
enum OpenCodePlugin {
  static func source(helper: String) -> String {
    javaScript(helperPath: javaScriptPath(helper))
  }

  /// `$HOME` is the shell's, not JavaScript's, so the plugin asks the
  /// runtime for the home directory and keeps the rest of the path.
  private static func javaScriptPath(_ helper: String) -> String {
    let prefix = "$HOME"
    guard helper.hasPrefix(prefix) else { return quoted(helper) }
    return "homedir() + " + quoted(String(helper.dropFirst(prefix.count)))
  }

  private static func quoted(_ value: String) -> String {
    var escaped = ""
    for character in value.unicodeScalars {
      switch character {
      case "\\", "\"": escaped += "\\" + String(character)
      case "\n": escaped += "\\n"
      default: escaped.unicodeScalars.append(character)
      }
    }
    return "\"\(escaped)\""
  }
}
