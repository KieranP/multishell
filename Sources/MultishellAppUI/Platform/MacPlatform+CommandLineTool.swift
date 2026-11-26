import AppKit
import MultishellAppCore
import MultishellCore

extension MacPlatform {
  /// The one script this app runs with administrator rights. `-h` replaces a
  /// link to a folder rather than writing inside the folder as root.
  static let installToolScript = """
    on installCommand(target, folder, link)
      return "mkdir -p " & quoted form of folder & " && ln -sfh " & quoted form of target & " " ¬
        & quoted form of link
    end installCommand

    on installTool(target, folder, link)
      do shell script (my installCommand(target, folder, link)) with administrator privileges
    end installTool
    """

  /// Static too, for the launch that hands its arguments over before any
  /// platform exists.
  nonisolated static var bundledHelper: URL? {
    Bundle.main.executableURL.flatMap(HelperHandOver.helper(inBundleOf:))
  }

  var bundledHelper: URL? { Self.bundledHelper }

  /// Links `/usr/local/bin/multishell` to this build's own stable link, through
  /// an administrator prompt, so the tool survives the app moving.
  func installCommandLineTool() throws {
    try AppleScriptRunner.call(
      Self.installToolScript,
      handler: "installTool",
      arguments: [
        Paths.buildHelperLink.path,
        HelperLink.commandLineToolLink.deletingLastPathComponent().path,
        HelperLink.commandLineToolLink.path,
      ],
    )
  }
}
