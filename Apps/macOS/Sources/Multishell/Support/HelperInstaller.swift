import AppKit
import Foundation
import MultishellCore

/// Keeps the helper reachable from outside the bundle.
///
/// The hook lines in `~/.claude/settings.json` reference a stable path under
/// the state directory; this refreshes that link at launch so a moved or
/// updated bundle still answers. The optional link in `/usr/local/bin` is for
/// people writing their own hooks, the way editors install their CLI.
enum HelperInstaller {
  static let commandLineToolLink = URL(fileURLWithPath: "/usr/local/bin/multishell")

  /// `Contents/Helpers/multishell`, or nil outside an app bundle.
  static var bundledHelper: URL? {
    let helper = Bundle.main.bundleURL
      .appendingPathComponent("Contents/Helpers/multishell", isDirectory: false)
    return FileManager.default.isExecutableFile(atPath: helper.path) ? helper : nil
  }

  /// Points `Paths.helperLink` at the bundled helper, replacing whatever was
  /// there. Nothing to do when there is no bundle.
  static func refreshLink() throws {
    guard let helper = bundledHelper else { return }
    let link = Paths.helperLink
    let manager = FileManager.default
    try manager.createDirectory(
      at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let existing = try? manager.destinationOfSymbolicLink(atPath: link.path),
      existing == helper.path
    {
      return
    }
    try? manager.removeItem(at: link)
    try manager.createSymbolicLink(at: link, withDestinationURL: helper)
  }

  static var isCommandLineToolInstalled: Bool {
    FileManager.default.fileExists(atPath: commandLineToolLink.path)
  }

  /// Links `/usr/local/bin/multishell` to the stable link, through an
  /// administrator prompt. To the link rather than the bundle, so the tool
  /// survives the app moving.
  static func installCommandLineTool() throws {
    let target = ShellQuoting.quote(Paths.helperLink.path)
    let link = ShellQuoting.quote(commandLineToolLink.path)
    let script =
      "do shell script \"mkdir -p /usr/local/bin && ln -sf \(target) \(link)\" with administrator privileges"
    var error: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&error)
    if let error {
      throw CommandLineToolInstallFailed(
        message: error[NSAppleScript.errorMessage] as? String ?? "\(error)")
    }
  }
}

struct CommandLineToolInstallFailed: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}
