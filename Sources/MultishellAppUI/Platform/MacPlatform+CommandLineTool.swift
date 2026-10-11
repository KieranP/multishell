import AppKit
import MultishellAppCore
import MultishellCore

extension MacPlatform {
  /// The one script this app runs with administrator rights.
  static let installToolScript = """
    on installTool(target, link)
      do shell script "mkdir -p /usr/local/bin && ln -sf " & quoted form of target & " " ¬
        & quoted form of link with administrator privileges
    end installTool
    """

  /// Static too, for the launch that hands its arguments over before any
  /// platform exists.
  nonisolated static var bundledHelper: URL? {
    Bundle.main.executableURL.flatMap(HelperHandOff.helper(inBundleOf:))
  }

  var bundledHelper: URL? { Self.bundledHelper }

  /// Links `/usr/local/bin/multishell` to this build's own stable link, through
  /// an administrator prompt, so the tool survives the app moving.
  func installCommandLineTool() throws {
    try AppleScriptRunner.call(
      Self.installToolScript,
      handler: "installTool",
      arguments: [Paths.buildHelperLink.path, HelperLink.commandLineToolLink.path],
    )
  }
}
