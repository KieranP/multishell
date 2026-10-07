import AppKit
import MultishellAppCore
import MultishellCore

extension MacPlatform {
  var bundledHelper: URL? {
    let helper = Bundle.main.bundleURL
      .appendingPathComponent("Contents/Helpers/multishell", isDirectory: false)
    return FileManager.default.isExecutableFile(atPath: helper.path) ? helper : nil
  }

  /// The one script this app runs with administrator rights.
  static let installToolScript = """
    on installTool(target, link)
      do shell script "mkdir -p /usr/local/bin && ln -sf " & quoted form of target & " " ¬
        & quoted form of link with administrator privileges
    end installTool
    """

  /// Links `/usr/local/bin/multishell` to the stable link, through an
  /// administrator prompt, so the tool survives the app moving.
  func installCommandLineTool() throws {
    try AppleScriptRunner.call(
      Self.installToolScript, handler: "installTool",
      arguments: [Paths.helperLink.path, HelperLink.commandLineToolLink.path])
  }
}
