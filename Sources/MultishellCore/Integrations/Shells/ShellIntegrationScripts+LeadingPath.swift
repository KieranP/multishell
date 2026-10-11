import Foundation

extension ShellIntegrationScripts {
  /// The integration's own reordering, for a line through a login shell that
  /// reads none of our files: POSIX but for zsh's and fish's own.
  public static func leadingPathStatement(forShellNamed name: String) -> String {
    switch name {
    case "zsh": resource("leading-path.zsh", in: "zsh")
    case "fish": resource("leading-path.fish", in: "fish")
    default: resource("leading-path.sh", in: "bash")
    }
  }
}
